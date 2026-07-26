using Travle.Model.Constants;
using Travle.Model.Messaging;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Imaging;
using Travle.Services.Messaging;
using Travle.Services.Recommender;
using Travle.Services.Security;
using Travle.Services.Validators;
using Travle.WebAPI.Authorization;
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

builder.Services.AddControllers()
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
builder.Services.AddScoped<IRoleApplicationService, RoleApplicationService>();
builder.Services.AddScoped<IDestinationService, DestinationService>();
builder.Services.AddScoped<ITourService, TourService>();

// Managed, cross-platform image codec for server-side thumbnails (stateless → singleton).
builder.Services.AddSingleton<IThumbnailGenerator, ImageSharpThumbnailGenerator>();
builder.Services.AddScoped<IRefreshTokenService, RefreshTokenService>();
builder.Services.AddScoped<IAccessManager, AccessManager>();
builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddScoped<ICryptoService, CryptoService>();

// Messaging: one long-lived RabbitMQ connection (singleton) + the email publisher the API uses to
// enqueue mail for the worker. RabbitMq settings come from the RabbitMq section (env in compose).
builder.Services.AddOptions<RabbitMqOptions>()
    .Bind(builder.Configuration.GetSection(RabbitMqOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();
builder.Services.AddSingleton<RabbitMqConnection>();
builder.Services.AddSingleton<IEmailPublisher, RabbitMqEmailPublisher>();
builder.Services.AddScoped<IPasswordResetService, PasswordResetService>();

// Recommender tuning (signal weights = the "model" per 04 §2; onboarding cap). Defaults in the
// options class match the doc; the Recommender config section overrides them.
builder.Services.AddOptions<RecommenderOptions>()
    .Bind(builder.Configuration.GetSection(RecommenderOptions.SectionName));

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

// Runtime seed for heavy data the migration seed can't carry as HasData: give every seeded destination
// a generated placeholder image + thumbnail so lists/details have images on first run (course §E).
await SeedDestinationImagesAsync(app);

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
