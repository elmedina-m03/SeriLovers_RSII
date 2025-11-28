using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using EasyNetQ;
using SeriLovers.API.Data;
using SeriLovers.API.Filters;
using SeriLovers.API.HostedServices;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Middleware;
using SeriLovers.API.Models;
using SeriLovers.API.Security;
using SeriLovers.API.Services;
using SeriLovers.API.Profiles;
using Swashbuckle.AspNetCore.Annotations;
using System.Linq;
using System.Reflection;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using QuestPDF.Infrastructure;

const string ExternalCookieScheme = "ExternalCookie";

var builder = WebApplication.CreateBuilder(args);

QuestPDF.Settings.License = LicenseType.Community;

// ============================================
// Database Configuration
// ============================================
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sqlOptions => sqlOptions.CommandTimeout(60)));

// ============================================
// ASP.NET Core Identity Configuration
// ============================================
builder.Services.AddIdentity<ApplicationUser, IdentityRole<int>>(options =>
{
    // Password requirements
    options.Password.RequireDigit = true;
    options.Password.RequireLowercase = true;
    options.Password.RequireUppercase = true;
    options.Password.RequireNonAlphanumeric = true;
    options.Password.RequiredLength = 8;
    
    // User requirements
    options.User.RequireUniqueEmail = true;
    options.SignIn.RequireConfirmedEmail = false;
    
    // Lockout settings
    options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    options.Lockout.MaxFailedAccessAttempts = 5;
    options.Lockout.AllowedForNewUsers = true;
})
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();

builder.Services.AddAutoMapper(typeof(AppMappingProfile).Assembly);

// ============================================
// JWT Authentication Configuration
// ============================================
var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secretKey = jwtSettings["SecretKey"] ?? "YourSuperSecretKeyThatIsAtLeast32CharactersLong!";
var issuer = jwtSettings["Issuer"] ?? "SeriLovers.API";
var audience = jwtSettings["Audience"] ?? "SeriLovers.API";

var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = issuer,
        ValidAudience = audience,
        IssuerSigningKey = key,
        // Map role claims from JWT token to ASP.NET Core claim types
        RoleClaimType = ClaimTypes.Role,
        NameClaimType = ClaimTypes.NameIdentifier
    };
    
    // Map JWT "role" claim to ASP.NET Core Role claim type
    options.Events = new Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerEvents
    {
        OnTokenValidated = context =>
        {
            // Ensure role claims are properly mapped
            if (context.Principal != null)
            {
                var roleClaims = context.Principal.FindAll("role").ToList();
                var identity = context.Principal.Identity as System.Security.Claims.ClaimsIdentity;
                if (identity != null)
                {
                    foreach (var roleClaim in roleClaims)
                    {
                        if (!identity.HasClaim(ClaimTypes.Role, roleClaim.Value))
                        {
                            identity.AddClaim(new Claim(ClaimTypes.Role, roleClaim.Value));
                        }
                    }
                }
            }
            return Task.CompletedTask;
        }
    };
})
.AddCookie(ExternalCookieScheme, options =>
{
    options.Cookie.Name = "SeriLovers.External";
    options.ExpireTimeSpan = TimeSpan.FromMinutes(10);
    options.SlidingExpiration = true;
})
.AddGoogle("Google", options =>
{
    options.SignInScheme = ExternalCookieScheme;
    var googleAuthSection = builder.Configuration.GetSection("Authentication:Google");
    options.ClientId = googleAuthSection["ClientId"] ?? string.Empty;
    options.ClientSecret = googleAuthSection["ClientSecret"] ?? string.Empty;
    options.SaveTokens = true;
    options.Scope.Add("email");
    options.Scope.Add("profile");
    options.CallbackPath = "/signin-google";
})
.AddScheme<AuthenticationSchemeOptions, BasicAuthHandler>("Basic", options => { });

// ============================================
// Service Registrations
// ============================================
builder.Services.AddScoped<ISeriesService, SeriesService>();
builder.Services.AddScoped<IActorService, ActorService>();
builder.Services.AddScoped<IGenreService, GenreService>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IAdminStatisticsService, AdminStatisticsService>();
builder.Services.AddScoped<IImageUploadService, ImageUploadService>();
// RabbitMQ connection - DISABLED
// builder.Services.AddSingleton<IBus>(sp =>
// {
//     var connectionString = builder.Configuration["RabbitMq:Connection"];
//     var logger = sp.GetRequiredService<ILogger<Program>>();
//     
//     if (string.IsNullOrWhiteSpace(connectionString))
//     {
//         logger.LogWarning("RabbitMQ connection string is not configured. Message bus will not be available.");
//         return null!; // Return null, will be handled gracefully
//     }
//     
//     try
//     {
//         logger.LogInformation("Attempting to connect to RabbitMQ...");
//         var bus = RabbitHutch.CreateBus(connectionString);
//         logger.LogInformation("Successfully connected to RabbitMQ.");
//         return bus;
//     }
//     catch (Exception ex)
//     {
//         logger.LogWarning(ex, "Failed to connect to RabbitMQ. The application will continue without message bus functionality.");
//         return null!; // Return null, will be handled gracefully
//     }
// });
// builder.Services.AddSingleton<IMessageBusService, MessageBusService>();
// builder.Services.AddHostedService<MessageBusSubscriberHostedService>();

// ============================================
// Controllers Configuration
// ============================================
builder.Services.AddControllers(options =>
{
    options.Filters.Add<GlobalExceptionFilter>();
});
builder.Services.AddHttpClient();

// ============================================
// CORS Configuration
// ============================================
builder.Services.AddCors(options =>
{
    options.AddPolicy("DevCors", policy =>
    {
        var isDevelopment = builder.Environment.IsDevelopment();

        if (isDevelopment)
        {
            // Development: allow everything to make local frontend work from any port
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        }
        else
        {
            // Production/staging: use configured allowed origins if present, otherwise fallback
            var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>();

            if (allowedOrigins != null && allowedOrigins.Length > 0)
            {
                policy.WithOrigins(allowedOrigins)
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            }
            else
            {
                policy.AllowAnyOrigin()
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            }
        }
    });
});

// ============================================
// Swagger/OpenAPI Configuration
// ============================================
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "SeriLovers API",
        Version = "v1",
        Description = "A comprehensive API for managing TV series, seasons, episodes, actors, and genres. " +
                      "Most endpoints require JWT authentication. Admin role is required for POST, PUT, and DELETE operations.",
        Contact = new OpenApiContact
        {
            Name = "SeriLovers API Support",
            Email = "support@serilovers.com"
        }
    });

    // JWT Bearer Authentication Configuration
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = @"JWT Authorization header using the Bearer scheme. 
                        Enter 'Bearer' [space] and then your token in the text input below.
                        Example: 'Bearer 12345abcdef'",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        Reference = new OpenApiReference
        {
            Type = ReferenceType.SecurityScheme,
            Id = "Bearer"
        }
    });

    // Apply security globally to all endpoints
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });

    // Include XML comments for better documentation
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }

    // Enable annotations to show [Authorize] attributes
    c.EnableAnnotations();

    // Customize operation IDs
    c.CustomOperationIds(apiDesc =>
    {
        var controllerActionDescriptor = apiDesc.ActionDescriptor as ControllerActionDescriptor;
        return controllerActionDescriptor?.MethodInfo.Name;
    });
});

// ============================================
// Build Application
// ============================================
var app = builder.Build();

// ============================================
// Middleware Pipeline
// ============================================

// Global exception handling middleware (must be early in pipeline)
app.UseMiddleware<GlobalExceptionHandlerMiddleware>();

// CORS (must be before UseAuthentication and UseAuthorization)
app.UseCors("DevCors");

// Swagger UI
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "SeriLovers API v1");
    c.RoutePrefix = string.Empty; // Set Swagger UI at the app's root
    c.DisplayRequestDuration();
    c.DocExpansion(Swashbuckle.AspNetCore.SwaggerUI.DocExpansion.List);
    c.EnableDeepLinking();
    c.EnableFilter();
    c.ShowExtensions();
    c.EnableValidator();
});

app.UseHttpsRedirection();

// Enable static file serving for uploaded images
app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// ============================================
// Database Seeding (Development only)
// ============================================
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var services = scope.ServiceProvider;
    await DbSeeder.Seed(services);
}

// ============================================
// Run Application
// ============================================
app.Run();
