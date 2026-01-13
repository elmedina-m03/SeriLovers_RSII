using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.StaticFiles;
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
using SeriLovers.API.Domain;
using SeriLovers.API.Domain.StateMachine;
using SeriLovers.API.Consumers;
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

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sqlOptions => sqlOptions.CommandTimeout(60)));

builder.Services.AddIdentity<ApplicationUser, IdentityRole<int>>(options =>
{
    // Relaxed password requirements for Development to allow "test" password
    if (builder.Environment.IsDevelopment())
    {
        options.Password.RequireDigit = false;
        options.Password.RequireLowercase = false;
        options.Password.RequireUppercase = false;
        options.Password.RequireNonAlphanumeric = false;
        options.Password.RequiredLength = 4;
    }
    else
    {
        options.Password.RequireDigit = true;
        options.Password.RequireLowercase = true;
        options.Password.RequireUppercase = true;
        options.Password.RequireNonAlphanumeric = true;
        options.Password.RequiredLength = 8;
    }
    options.User.RequireUniqueEmail = true;
    options.SignIn.RequireConfirmedEmail = false;
    options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    options.Lockout.MaxFailedAccessAttempts = 5;
    options.Lockout.AllowedForNewUsers = true;
})
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();

builder.Services.AddAutoMapper(typeof(AppMappingProfile).Assembly);

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
        RoleClaimType = ClaimTypes.Role,
        NameClaimType = ClaimTypes.NameIdentifier
    };
    
    options.Events = new Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerEvents
    {
        OnTokenValidated = context =>
        {
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

builder.Services.AddScoped<ISeriesService, SeriesService>();
builder.Services.AddScoped<IActorService, ActorService>();
builder.Services.AddScoped<IGenreService, GenreService>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IAdminStatisticsService, AdminStatisticsService>();
builder.Services.AddScoped<IImageUploadService, ImageUploadService>();
builder.Services.AddScoped<RecommendationService>();
builder.Services.AddScoped<ChallengeService>();
builder.Services.AddScoped<ISeriesWatchingStateService, SeriesWatchingStateService>();

builder.Services.AddScoped<ToWatchState>();
builder.Services.AddScoped<InProgressState>();
builder.Services.AddScoped<FinishedState>();

// RabbitMQ Event Consumers
builder.Services.AddScoped<EpisodeWatchedEventConsumer>();
builder.Services.AddScoped<ReviewCreatedEventConsumer>();

builder.Services.AddSingleton<IBus>(sp =>
{
    var connectionString = Environment.GetEnvironmentVariable("RABBITMQ_CONNECTION") 
        ?? builder.Configuration["RabbitMq:Connection"]
        ?? builder.Configuration.GetConnectionString("RabbitMQ");
    
    var logger = sp.GetRequiredService<ILogger<Program>>();
    
    if (string.IsNullOrWhiteSpace(connectionString))
    {
        logger.LogWarning("RabbitMQ connection string is not configured. Message bus will not be available.");
        return null!;
    }
    
    try
    {
        logger.LogInformation("Attempting to connect to RabbitMQ...");
        var bus = RabbitHutch.CreateBus(connectionString);
        logger.LogInformation("Successfully connected to RabbitMQ.");
        return bus;
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "Failed to connect to RabbitMQ. The application will continue without message bus functionality.");
        return null!;
    }
});
builder.Services.AddSingleton<IMessageBusService, MessageBusService>();
builder.Services.AddHostedService<MessageBusSubscriberHostedService>();

builder.Services.AddControllers(options =>
{
    options.Filters.Add<GlobalExceptionFilter>();
});
builder.Services.AddHttpClient();

builder.Services.AddCors(options =>
{
    options.AddPolicy("DevCors", policy =>
    {
        var isDevelopment = builder.Environment.IsDevelopment();

        if (isDevelopment)
        {
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        }
        else
        {
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

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = @"JWT Authorization header using the Bearer scheme. Enter 'Bearer' [space] and then your token.",
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

    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }

    c.EnableAnnotations();

    c.CustomOperationIds(apiDesc =>
    {
        var controllerActionDescriptor = apiDesc.ActionDescriptor as ControllerActionDescriptor;
        return controllerActionDescriptor?.MethodInfo.Name;
    });
});

var app = builder.Build();

app.UseMiddleware<GlobalExceptionHandlerMiddleware>();
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


app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = ctx =>
    {
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Origin", "*");
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Methods", "GET");
        ctx.Context.Response.Headers.Append("Cache-Control", "public,max-age=3600");
    }
});

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// Apply database migrations automatically with retry logic
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var context = services.GetRequiredService<ApplicationDbContext>();
    var logger = services.GetRequiredService<ILogger<Program>>();
    
    var maxRetries = 10;
    var delay = TimeSpan.FromSeconds(5);
    
    for (int i = 0; i < maxRetries; i++)
    {
        try
        {
            logger.LogInformation("Applying database migrations... (Attempt {Attempt}/{MaxRetries})", i + 1, maxRetries);
            await context.Database.MigrateAsync();
            logger.LogInformation("Database migrations applied successfully.");
            break;
        }
        catch (Exception ex)
        {
            if (i == maxRetries - 1)
            {
                logger.LogError(ex, "Failed to apply database migrations after {MaxRetries} attempts.", maxRetries);
                throw;
            }
            
            logger.LogWarning(ex, "Database not ready yet. Retrying in {Delay} seconds...", delay.TotalSeconds);
            await Task.Delay(delay);
        }
    }    
    // CRITICAL: Fix all EpisodeProgress records with NULL IsCompleted before seeding
    try
    {
        logger.LogInformation("Starting EpisodeProgress cleanup: fixing all NULL IsCompleted records.");
        
        // Use raw SQL to update NULL values to true (bypassing EF Core tracking issues)
        var nullCount = await context.Database.ExecuteSqlRawAsync(
            "UPDATE EpisodeProgresses SET IsCompleted = 1 WHERE IsCompleted IS NULL");
        
        logger.LogInformation("Fixed {Count} EpisodeProgress records with NULL IsCompleted.", nullCount);
        
        // Also remove any records with IsCompleted = false
        var incompleteRecords = await context.EpisodeProgresses
            .Where(ep => !ep.IsCompleted)
            .ToListAsync();
        
        if (incompleteRecords.Any())
        {
            var count = incompleteRecords.Count;
            logger.LogWarning("Found {Count} incomplete EpisodeProgress records. Removing them to prevent data inconsistencies.", count);
            context.EpisodeProgresses.RemoveRange(incompleteRecords);
            await context.SaveChangesAsync();
            logger.LogInformation("Successfully removed {Count} incomplete EpisodeProgress records.", count);
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Error cleaning up incomplete EpisodeProgress records. Continuing anyway.");
        // Don't throw - continue with startup
    }
}

using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    await DbSeeder.SeedCatalogDataAsync(services);
}

if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var services = scope.ServiceProvider;
    await DbSeeder.SeedDevelopmentDataAsync(services);
}

app.Run();
