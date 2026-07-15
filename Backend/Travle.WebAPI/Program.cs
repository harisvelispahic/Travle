using Travle.Common.Services.CryptoService;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services;
using Travle.Services.Database;
using Travle.Services.ProductStateMachine;
using Travle.Services.Validators;
using Travle.WebAPI.Middleware;
using Travle.WebAPI.Services;
using Travle.WebAPI.Services.AccessManager;
using FluentValidation;
using Mapster;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Scalar.AspNetCore;
using System.Diagnostics;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IAuthenticatedUserAccessor, HttpAuthenticatedUserAccessor>();

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

// configure a few mappings explicitly if needed (optional)
// Mapster will automatically map same-named properties, but configuration
// ensures any custom rules or future needs can be added here.
TypeAdapterConfig<Product, ProductResponse>.NewConfig().IgnoreNullValues(true);
TypeAdapterConfig<Category, CategoryResponse>.NewConfig().IgnoreNullValues(true);
TypeAdapterConfig<User, UserResponse>.NewConfig().IgnoreNullValues(true);
TypeAdapterConfig<UserUpdateRequest, User>.NewConfig().IgnoreNullValues(true);
TypeAdapterConfig<ProductType, ProductTypeResponse>.NewConfig().IgnoreNullValues(true);
TypeAdapterConfig<UnitOfMeasure, UnitOfMeasureResponse>.NewConfig().IgnoreNullValues(true);
TypeAdapterConfig<Asset, AssetResponse>.NewConfig().IgnoreNullValues(true);
TypeAdapterConfig<ProductReview, ProductReviewResponse>.NewConfig()
    .Map(dest => dest.ReviewerDisplayName, src => $"{src.User.FirstName} {src.User.LastName}".Trim());
TypeAdapterConfig<Order, OrderResponse>.NewConfig()
    .Map(dest => dest.Status, src => (int)src.Status);
TypeAdapterConfig<OrderItem, OrderItemResponse>.NewConfig()
    .Map(dest => dest.ProductName, src => src.Product != null ? src.Product.Name : string.Empty);


// register application services
builder.Services.AddScoped<IProductService, ProductService>();
builder.Services.AddScoped<BaseProductState>();
builder.Services.AddScoped<InitialProductState>();
builder.Services.AddScoped<DraftProductState>();
builder.Services.AddScoped<ActiveProductState>();

// category service
builder.Services.AddScoped<ICategoryService, CategoryService>();
// product type service
builder.Services.AddScoped<IProductTypeService, ProductTypeService>();
// unit of measure service
builder.Services.AddScoped<IUnitOfMeasureService, UnitOfMeasureService>();
// user service
builder.Services.AddScoped<IUserService, UserService>();

builder.Services.AddScoped<IAssetService, AssetService>();


builder.Services.AddScoped<IRefreshTokenService, RefreshTokenService>();

builder.Services.AddScoped<IAccessManager, AccessManager>();

builder.Services.AddScoped<ICryptoService, CryptoService>();

builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddScoped<IProductReviewService, ProductReviewService>();

// Register every FluentValidation validator in the Travle.Services assembly (Scoped) in one
// sweep, so new validators are picked up automatically without editing Program.cs.
builder.Services.AddValidatorsFromAssemblyContaining<UserInsertValidator>();

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

builder.Services.AddAuthentication(options => // dodavanje authentfikacije i autorizacije u projekat
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
}).AddJwtBearer(o =>
{
    o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidIssuer = builder.Configuration["JwtToken:Issuer"],
        ValidAudience = builder.Configuration["JwtToken:Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["JwtToken:SecretKey"] ?? string.Empty)),
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ClockSkew = TimeSpan.Zero
    };
});
builder.Services.AddAuthorization();


builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(
    options =>
    {
        options.SwaggerDoc("v1", new OpenApiInfo
        {
            Version = "v1",
            Title = "Travle API",
            Description = "API for managing products and categories in the Travle application"
        });

        var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
        options.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory, xmlFile));

        var jwtSecurityScheme = new OpenApiSecurityScheme
        {
            BearerFormat = "JWT",
            Name = "JWT Authentication",
            In = ParameterLocation.Header,
            Type = SecuritySchemeType.Http,
            Scheme = JwtBearerDefaults.AuthenticationScheme,
        };

        options.AddSecurityDefinition(JwtBearerDefaults.AuthenticationScheme, jwtSecurityScheme);
        options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
                {
                    { new OpenApiSecuritySchemeReference(JwtBearerDefaults.AuthenticationScheme, document), new List<string>() }
                });
    });

var app = builder.Build();

// Must be the first middleware so it wraps the entire pipeline: any exception thrown downstream
// is routed through the registered IExceptionHandler chain.
app.UseExceptionHandler();

// Configure the HTTP request pipeline.
//if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();


    app.UseSwagger();
    app.UseSwaggerUI();
}

//app.UseHttpsRedirection();

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

app.Run();
