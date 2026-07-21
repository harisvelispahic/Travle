using Travle.Model.Constants;
using Travle.Model.Messaging;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services;
using Travle.Services.Authorization;
using Travle.Services.Database;
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

var builder = WebApplication.CreateBuilder(args);

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

// Add Entity Framework Core DbContext
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
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

//app.UseHttpsRedirection();

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

app.Run();
