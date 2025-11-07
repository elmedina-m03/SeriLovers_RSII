using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using SeriLovers.API.Data;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Middleware;
using SeriLovers.API.Models;
using SeriLovers.API.Services;
using SeriLovers.API.Profiles;
using Swashbuckle.AspNetCore.Annotations;
using System.Reflection;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// ============================================
// Database Configuration
// ============================================
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

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
        IssuerSigningKey = key
    };
});

// ============================================
// Service Registrations
// ============================================
builder.Services.AddScoped<ISeriesService, SeriesService>();
builder.Services.AddScoped<IActorService, ActorService>();
builder.Services.AddScoped<IGenreService, GenreService>();
builder.Services.AddScoped<ITokenService, TokenService>();

// ============================================
// Controllers Configuration
// ============================================
builder.Services.AddControllers();

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
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// ============================================
// Database Seeding
// ============================================
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    await DbSeeder.Seed(services);
}

// ============================================
// Run Application
// ============================================
app.Run();
