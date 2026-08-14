using Travle.Model.Constants;
using Travle.Model.Messaging;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services;
using Travle.Services.Authorization;
using Travle.Services.BookingStateMachine;
using Travle.Services.Database;
using Travle.Services.Database.Seeding;
using Travle.Services.Imaging;
using Travle.Services.Messaging;
using Travle.Services.Notifications;
using Travle.Services.Payments;
using Travle.Services.Recommender;
using Travle.Services.Reports;
using Travle.Services.Security;
using Travle.Services.Validators;
using Travle.WebAPI.Authorization;
using Travle.WebAPI.Filters;
using Travle.WebAPI.Hubs;
using Travle.WebAPI.Middleware;
using Travle.WebAPI.OpenApi;
using Travle.WebAPI.Options;
using Travle.WebAPI.Services;
using Travle.WebAPI.Services.AccessManager;
using FluentValidation;
using Mapster;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Scalar.AspNetCore;
using System.Diagnostics;
using System.Security.Claims;
using System.Text;

// Load the repo-root .env for local (non-Docker) runs, so the same secrets docker-compose injects
// into the container are also available to `dotnet run`. Walks up from the working directory to find
// it; a missing file (as inside the container, where compose supplies the vars) is a no-op. NoClobber
// leaves any already-set environment variable untouched, so compose-provided values always win.
for (var dir = new DirectoryInfo(Directory.GetCurrentDirectory()); dir is not null; dir = dir.Parent)
{
    var envPath = Path.Combine(dir.FullName, ".env");
    if (File.Exists(envPath))
    {
        DotNetEnv.Env.NoClobber().Load(envPath);
        break;
    }
}

var builder = WebApplication.CreateBuilder(args);

// QuestPDF Community licence (free under the revenue threshold — fine for a seminar project). Must be
// set once before any report PDF is generated. See docs/context §Phase 11.
QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

// CORS policy names and the origins it allows (explicit, from configuration — never AllowAnyOrigin).
const string TravleCorsPolicy = "TravleCors";
var corsAllowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];

// Add services to the container.

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IAuthenticatedUserAccessor, HttpAuthenticatedUserAccessor>();
builder.Services.AddScoped<IAppAuthorizationService, AppAuthorizationService>();

// Global exception-handling pipeline: a chain of IExceptionHandler implementations invoked in
// registration order (specific first, generic last — the try/catch/catch mental model). The
// fallback GlobalExceptionHandler is registered last and always handles. See
// docs/context/09-exception-handling.md.
builder.Services.AddExceptionHandler<TravleExceptionHandler>();
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.AddControllers(options =>
    {
        // After every successful action, flush any notifications staged during it (SignalR push + email)
        // now that their transaction has committed. Global so no controller has to remember to.
        options.Filters.Add<NotificationFlushFilter>();
    })
    .ConfigureApiBehaviorOptions(options =>
    {
        // Keep model-binding / [ApiController] validation failures in the same ErrorResponse
        // shape the exception handlers produce, so clients only ever parse one error format.
        options.InvalidModelStateResponseFactory = context =>
        {
            var errors = context.ModelState
                .Where(kvp => kvp.Value is { Errors.Count: > 0 })
                .ToDictionary(
                    kvp => string.IsNullOrEmpty(kvp.Key) ? "request" : kvp.Key,
                    kvp => kvp.Value!.Errors.Select(e => e.ErrorMessage).ToArray());

            var body = new ErrorResponse
            {
                Message = errors.Values.SelectMany(v => v).FirstOrDefault() ?? "One or more validation errors occurred.",
                Errors = errors,
                TraceId = Activity.Current?.Id ?? context.HttpContext.TraceIdentifier
            };

            return new BadRequestObjectResult(body) { ContentTypes = { "application/json" } };
        };
    });

// CORS configured once with explicit origins from configuration (course §3.4). Native Flutter
// clients don't send an Origin, but a browser client (or the API's own docs UI) relies on this.
builder.Services.AddCors(options =>
{
    options.AddPolicy(TravleCorsPolicy, policy =>
    {
        if (corsAllowedOrigins.Length > 0)
        {
            policy.WithOrigins(corsAllowedOrigins).AllowAnyHeader().AllowAnyMethod();
        }
    });
});

// Add Entity Framework Core DbContext
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException(
        "No connection string configured. Set ConnectionStrings__DefaultConnection (docker-compose supplies "
        + "it from CONNECTION_STRING; local runs read it from the repo-root .env via DotNetEnv).");
builder.Services.AddDbContext<TravleDbContext>(options =>
    options.UseSqlServer(connectionString)
);

// register Mapster for object mapping
builder.Services.AddMapster();

// Explicit Mapster rules. Same-named properties map automatically; these add the custom behaviour
// the User mappings need: flatten the roles and city name on the way out, and ignore nulls on a
// partial profile update so an unspecified field never overwrites the stored value.
TypeAdapterConfig<User, UserResponse>.NewConfig()
    .Map(dest => dest.Roles, src => src.UserRoles.Select(ur => ur.Role.Name).ToList())
    .Map(dest => dest.CityName, src => src.City != null ? src.City.Name : null);
TypeAdapterConfig<UserUpdateRequest, User>.NewConfig().IgnoreNullValues(true);

// Role application: flatten the applicant/role/region/decider names and the status enum on the way
// out, and expose only whether a document exists (its bytes ship via the dedicated download endpoint).
TypeAdapterConfig<RoleApplication, RoleApplicationResponse>.NewConfig()
    .Map(dest => dest.Username, src => src.User != null ? src.User.Username : null)
    .Map(dest => dest.ApplicantName, src => src.User != null ? src.User.FirstName + " " + src.User.LastName : null)
    .Map(dest => dest.RoleName, src => src.Role != null ? src.Role.Name : null)
    .Map(dest => dest.RegionName, src => src.Region != null ? src.Region.Name : null)
    .Map(dest => dest.DecidedByUsername, src => src.DecidedByUser != null ? src.DecidedByUser.Username : null)
    .Map(dest => dest.HasDocument, src => src.Document != null)
    .Map(dest => dest.Status, src => src.Status.ToString());

// register application services
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IRoleService, RoleService>();
builder.Services.AddScoped<IRoleApplicationService, RoleApplicationService>();
builder.Services.AddScoped<IDestinationService, DestinationService>();
builder.Services.AddScoped<ITourService, TourService>();
builder.Services.AddScoped<IBookingService, BookingService>();
builder.Services.AddScoped<IDestinationReviewService, DestinationReviewService>();
builder.Services.AddScoped<ITourReviewService, TourReviewService>();
builder.Services.AddScoped<IFavoriteService, FavoriteService>();

// Reporting module (Phase 11): dashboard + PDF reports + organizer statistics. Read-only aggregates;
// the PDFs are composed with QuestPDF (Community licence set below).
builder.Services.AddScoped<IReportService, ReportService>();

// Notifications (Phase 9). The dispatcher (write side) and the read service are request-scoped; the
// SignalR push adapter bridges the dispatcher to the hub. AddSignalR wires the hub runtime; the hub is
// mapped after auth below. See docs/notifications-and-signalr.md.
builder.Services.AddScoped<INotificationDispatcher, NotificationDispatcher>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<INotificationRealtimePush, SignalRNotificationPush>();
builder.Services.AddSignalR();

// Booking state machine: the base acts as the factory host injected into the service, and each concrete
// state is a scoped service resolved by BaseBookingState.GetState per the persisted status (state pattern).
builder.Services.AddScoped<BaseBookingState>();
builder.Services.AddScoped<InitialBookingState>();
builder.Services.AddScoped<PaymentInProgressBookingState>();
builder.Services.AddScoped<PendingBookingState>();
builder.Services.AddScoped<ConfirmedBookingState>();
builder.Services.AddScoped<CompletedBookingState>();
builder.Services.AddScoped<CancelledBookingState>();
builder.Services.AddScoped<ExpiredBookingState>();

// In-process scheduler (IHostedService): expires 15-min PaymentInProgress holds, auto-completes Confirmed
// bookings past their schedule end, and raises the 24-hour pre-tour reminder. Lives in the API, not the
// RabbitMQ worker container. The reminder window is configurable (BookingReminder section).
builder.Services.AddOptions<BookingReminderOptions>()
    .Bind(builder.Configuration.GetSection(BookingReminderOptions.SectionName))
    .ValidateDataAnnotations();
builder.Services.AddHostedService<BookingLifecycleWorker>();

// Payments: Stripe settings bound once and validated at startup (fail fast on a missing secret key, like
// JWT). StripeService is the only caller of the Stripe SDK; PaymentService owns the amount/fee snapshot
// and the Payment-row lifecycle. Test-mode only — see docs/payments-and-stripe.md.
builder.Services.AddOptions<PaymentOptions>()
    .Bind(builder.Configuration.GetSection(PaymentOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();
builder.Services.AddScoped<IStripeService, StripeService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IRefundService, RefundService>();

// Managed, cross-platform image codec for server-side thumbnails (stateless → singleton).
builder.Services.AddSingleton<IThumbnailGenerator, ImageSharpThumbnailGenerator>();
builder.Services.AddScoped<IRefreshTokenService, RefreshTokenService>();
builder.Services.AddScoped<IAccessManager, AccessManager>();
builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddScoped<ICryptoService, CryptoService>();
// Backs the JwtBearer OnTokenValidated gate: a cached read of each user's security stamp + suspension
// flag, so every request can reject revoked/suspended tokens. See docs/auth-token-invalidation.md.
builder.Services.AddScoped<IUserSecurityStore, UserSecurityStore>();

// Messaging: one long-lived RabbitMQ connection (singleton) + the email publisher the API uses to
// enqueue mail for the worker. RabbitMq settings come from the RabbitMq section (env in compose).
builder.Services.AddOptions<RabbitMqOptions>()
    .Bind(builder.Configuration.GetSection(RabbitMqOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();
builder.Services.AddSingleton<RabbitMqConnection>();
builder.Services.AddSingleton<IEmailPublisher, RabbitMqEmailPublisher>();
builder.Services.AddScoped<IPasswordResetService, PasswordResetService>();

// Recommender tuning: signal weights + scoring constants = the "model" (04 §2/§3); onboarding cap.
// Defaults in the options class match the doc; the Recommender config section overrides them.
builder.Services.AddOptions<RecommenderOptions>()
    .Bind(builder.Configuration.GetSection(RecommenderOptions.SectionName));

// On-demand recommender (04 §4): IMemoryCache backs both the per-user result cache (invalidated on
// strong interactions) and the hot approved-destination catalog. The cache wrapper holds no per-request
// state (singleton); the scoring service is scoped because it uses the DbContext.
builder.Services.AddMemoryCache();
builder.Services.AddSingleton<IRecommendationCache, RecommendationCache>();
builder.Services.AddScoped<IRecommendationService, RecommendationService>();

// Reference-data CRUD services (Country → Region → City chaining + catalog lookups).
builder.Services.AddScoped<ICountryService, CountryService>();
builder.Services.AddScoped<IRegionService, RegionService>();
builder.Services.AddScoped<ICityService, CityService>();
builder.Services.AddScoped<IDestinationCategoryService, DestinationCategoryService>();
builder.Services.AddScoped<ITourTypeService, TourTypeService>();
builder.Services.AddScoped<ITagService, TagService>();
builder.Services.AddScoped<IRefundPolicyTierService, RefundPolicyTierService>();
builder.Services.AddScoped<IBookingStatusService, BookingStatusService>();

// Register every FluentValidation validator in the Travle.Services assembly (Scoped) in one
// sweep, so new validators are picked up automatically without editing Program.cs.
builder.Services.AddValidatorsFromAssemblyContaining<UserRegisterValidator>();

// OpenAPI document (Microsoft.AspNetCore.OpenApi) + a transformer that declares the JWT bearer
// scheme, so Scalar shows an auth field you fill once. Learn more: https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer<BearerSecuritySchemeTransformer>();
});

// JWT settings bound once and validated at startup (fail fast on a missing or too-short key).
builder.Services.AddOptions<JwtOptions>()
    .Bind(builder.Configuration.GetSection(JwtOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();

var jwtOptions = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>()
    ?? throw new InvalidOperationException($"Missing '{JwtOptions.SectionName}' configuration section.");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
}).AddJwtBearer(o =>
{
    o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidIssuer = jwtOptions.Issuer,
        ValidAudience = jwtOptions.Audience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SecretKey)),
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ClockSkew = TimeSpan.Zero,
        RoleClaimType = ClaimTypes.Role,
        NameClaimType = ClaimTypes.NameIdentifier
    };

    // A WebSocket handshake can't carry an Authorization header, so the SignalR client passes the JWT as
    // an `access_token` query parameter. Accept it only for the hub path; every other request keeps using
    // the standard Authorization header. The token is still fully signature-validated above.
    o.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            if (!string.IsNullOrEmpty(accessToken)
                && context.HttpContext.Request.Path.StartsWithSegments("/hubs"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        },

        // Revocability gate. A stateless JWT is otherwise valid until it expires, so on every
        // authenticated request we reject a token whose account is suspended or whose security stamp no
        // longer matches the user's current one (any auth change bumps it — suspend, role change,
        // password change, logout). The two values are read through a short-lived cache, never the
        // tokens themselves. See docs/auth-token-invalidation.md.
        OnTokenValidated = async context =>
        {
            var principal = context.Principal;
            if (principal is null
                || !int.TryParse(principal.FindFirstValue(ClaimTypes.NameIdentifier), out var userId))
            {
                context.Fail("Invalid token subject.");
                return;
            }

            var store = context.HttpContext.RequestServices.GetRequiredService<IUserSecurityStore>();
            var state = await store.GetAsync(userId, context.HttpContext.RequestAborted);

            if (state is null || state.IsSuspended)
            {
                context.Fail("This account is not active.");
                return;
            }

            var tokenStamp = principal.FindFirstValue(TravleClaimTypes.SecurityStamp);
            if (!string.Equals(tokenStamp, state.SecurityStamp, StringComparison.Ordinal))
            {
                context.Fail("This session is no longer valid.");
            }
        }
    };
});

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(AuthPolicies.Authenticated, policy => policy.RequireAuthenticatedUser());
    options.AddPolicy(AuthPolicies.AdminOnly, policy => policy.RequireRole(RoleNames.Admin));
    options.AddPolicy(AuthPolicies.OrganizerOnly, policy => policy.RequireRole(RoleNames.Organizer));
    options.AddPolicy(AuthPolicies.CuratorOnly, policy => policy.RequireRole(RoleNames.Curator));
    options.AddPolicy(AuthPolicies.TravelerOnly, policy => policy.RequireRole(RoleNames.Traveler));
});


var app = builder.Build();

// Apply migrations (and thereby the seed) on startup so a fresh `docker compose up` reaches a
// migrated, seeded database with no manual step. SQL Server can still be mid-boot when the API
// starts, so retry transient connection failures with a short backoff before giving up.
await ApplyMigrationsAsync(app);

// Comprehensive runtime seed: normalises the reference regions into the final taxonomy, expands the full
// geographic + classification reference set, and generates the bulk demo content (extra users, the
// city-by-city destination catalogue, tours + schedules, bookings/payments/refunds, reviews, favourites,
// recommender interactions, notifications, role applications). Idempotent; runs before image seeding so
// every new destination is picked up for a placeholder image below.
await SeedBulkDataAsync(app);

// Runtime seed for heavy data the migration seed can't carry as HasData: give every seeded destination
// a generated placeholder image + thumbnail so lists/details have images on first run (course §E).
await SeedDestinationImagesAsync(app);

// Idempotent runtime seed: backfill each category's onboarding-card description and (when its embedded PNG
// asset ships) its illustration + thumbnail, so the mobile onboarding grid is populated on a fresh run.
await SeedCategoryContentAsync(app);

// Must be the first middleware so it wraps the entire pipeline: any exception thrown downstream
// is routed through the registered IExceptionHandler chain.
app.UseExceptionHandler();

// Configure the HTTP request pipeline. OpenAPI JSON + Scalar API reference (Scalar reads the
// document from MapOpenApi; the bearer scheme added by the transformer gives it an auth field).
app.MapOpenApi();
app.MapScalarApiReference(options =>
{
    options.WithTitle("Travle API")
           .AddPreferredSecuritySchemes("Bearer");
});

app.UseCors(TravleCorsPolicy);

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

// Real-time notifications hub. Authorization is enforced by [Authorize] on the hub; the access_token
// query param (wired above) authenticates the WebSocket handshake.
app.MapHub<NotificationHub>("/hubs/notifications");

app.Run();

// Migrates the database on startup, retrying while SQL Server finishes booting. Runs in its own DI
// scope; the compose healthcheck already gates startup, so the retry is a belt-and-suspenders guard.
static async Task ApplyMigrationsAsync(WebApplication app)
{
    const int maxAttempts = 12;
    var delay = TimeSpan.FromSeconds(3);

    await using var scope = app.Services.CreateAsyncScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<TravleDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();

    for (var attempt = 1; ; attempt++)
    {
        try
        {
            await dbContext.Database.MigrateAsync();
            logger.LogInformation("Database migrations applied successfully.");
            return;
        }
        catch (Exception ex) when (attempt < maxAttempts)
        {
            logger.LogWarning(ex, "Database not ready (attempt {Attempt}/{Max}); retrying in {Seconds}s.",
                attempt, maxAttempts, delay.TotalSeconds);
            await Task.Delay(delay);
        }
    }
}

// Comprehensive runtime seed (see BulkSeeder): reference-data expansion + bulk demo content. Runs once on
// a fresh database in its own scope, inside a transaction, computing all dates relative to "now"; guarded
// so subsequent boots are a no-op.
static async Task SeedBulkDataAsync(WebApplication app)
{
    await using var scope = app.Services.CreateAsyncScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<TravleDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    await BulkSeeder.SeedAsync(dbContext, logger);
}

// Idempotent runtime seed: every destination that has no image gets a generated placeholder image plus
// its thumbnail. Binary blobs can't ride along in HasData, so this runs once on startup after migration;
// subsequent runs find images already present and do nothing.
static async Task SeedDestinationImagesAsync(WebApplication app)
{
    await using var scope = app.Services.CreateAsyncScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<TravleDbContext>();
    var thumbnailGenerator = scope.ServiceProvider.GetRequiredService<IThumbnailGenerator>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();

    var destinationsWithoutImages = await dbContext.Destinations
        .Where(d => !d.Images.Any())
        .Select(d => new { d.Id, d.Name })
        .ToListAsync();

    if (destinationsWithoutImages.Count == 0)
    {
        return;
    }

    foreach (var destination in destinationsWithoutImages)
    {
        var image = await thumbnailGenerator.GeneratePlaceholderJpegAsync(destination.Name);
        var (thumbnail, contentType) = await thumbnailGenerator.GenerateThumbnailAsync(image);

        dbContext.DestinationImages.Add(new DestinationImage
        {
            DestinationId = destination.Id,
            ImageData = image,
            ThumbnailData = thumbnail,
            ContentType = contentType,
            SortOrder = 0
        });
    }

    await dbContext.SaveChangesAsync();
    logger.LogInformation("Seeded placeholder images for {Count} destination(s).", destinationsWithoutImages.Count);
}

// Idempotent runtime seed: backfill each category's onboarding description and (when its embedded PNG asset
// ships) its illustration + thumbnail. Runs once after migration; subsequent boots find them present and do
// nothing. Owned by the Services assembly (which holds the embedded images) — see CategoryContentSeeder.
static async Task SeedCategoryContentAsync(WebApplication app)
{
    await using var scope = app.Services.CreateAsyncScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<TravleDbContext>();
    var thumbnailGenerator = scope.ServiceProvider.GetRequiredService<IThumbnailGenerator>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();

    await CategoryContentSeeder.SeedAsync(dbContext, thumbnailGenerator, logger);
}
