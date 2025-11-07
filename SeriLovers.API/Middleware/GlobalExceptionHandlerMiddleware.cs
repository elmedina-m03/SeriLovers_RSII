using System.Net;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Models.DTOs;

namespace SeriLovers.API.Middleware
{
    public class GlobalExceptionHandlerMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<GlobalExceptionHandlerMiddleware> _logger;
        private readonly IWebHostEnvironment _environment;

        public GlobalExceptionHandlerMiddleware(
            RequestDelegate next,
            ILogger<GlobalExceptionHandlerMiddleware> logger,
            IWebHostEnvironment environment)
        {
            _next = next;
            _logger = logger;
            _environment = environment;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An unhandled exception occurred: {Message}", ex.Message);
                await HandleExceptionAsync(context, ex);
            }
        }

        private async Task HandleExceptionAsync(HttpContext context, Exception exception)
        {
            context.Response.ContentType = "application/json";
            var response = context.Response;

            var errorResponse = new ErrorResponseDto
            {
                TraceId = context.TraceIdentifier,
                Timestamp = DateTime.UtcNow
            };

            switch (exception)
            {
                case UnauthorizedAccessException:
                    errorResponse.StatusCode = (int)HttpStatusCode.Unauthorized;
                    errorResponse.Message = "Unauthorized access";
                    errorResponse.Details = exception.Message;
                    response.StatusCode = (int)HttpStatusCode.Unauthorized;
                    break;

                case ArgumentException argEx:
                    errorResponse.StatusCode = (int)HttpStatusCode.BadRequest;
                    errorResponse.Message = "Invalid argument";
                    errorResponse.Details = argEx.Message;
                    response.StatusCode = (int)HttpStatusCode.BadRequest;
                    break;

                case KeyNotFoundException:
                    errorResponse.StatusCode = (int)HttpStatusCode.NotFound;
                    errorResponse.Message = "Resource not found";
                    errorResponse.Details = exception.Message;
                    response.StatusCode = (int)HttpStatusCode.NotFound;
                    break;

                case DbUpdateConcurrencyException:
                    errorResponse.StatusCode = (int)HttpStatusCode.Conflict;
                    errorResponse.Message = "Concurrency conflict";
                    errorResponse.Details = "The resource has been modified by another user. Please refresh and try again.";
                    response.StatusCode = (int)HttpStatusCode.Conflict;
                    break;

                case DbUpdateException dbEx:
                    errorResponse.StatusCode = (int)HttpStatusCode.BadRequest;
                    errorResponse.Message = "Database operation failed";
                    
                    // Extract more specific error information
                    if (dbEx.InnerException != null)
                    {
                        var innerMessage = dbEx.InnerException.Message;
                        if (innerMessage.Contains("UNIQUE") || innerMessage.Contains("duplicate"))
                        {
                            errorResponse.Message = "Duplicate entry detected";
                            errorResponse.Details = "A record with the same unique value already exists.";
                        }
                        else if (innerMessage.Contains("FOREIGN KEY"))
                        {
                            errorResponse.Message = "Referential integrity violation";
                            errorResponse.Details = "Cannot perform this operation due to foreign key constraints.";
                        }
                        else
                        {
                            errorResponse.Details = _environment.IsDevelopment() 
                                ? innerMessage 
                                : "A database error occurred. Please try again later.";
                        }
                    }
                    else
                    {
                        errorResponse.Details = _environment.IsDevelopment() 
                            ? dbEx.Message 
                            : "A database error occurred. Please try again later.";
                    }
                    response.StatusCode = (int)HttpStatusCode.BadRequest;
                    break;

                default:
                    errorResponse.StatusCode = (int)HttpStatusCode.InternalServerError;
                    errorResponse.Message = "An error occurred while processing your request";
                    errorResponse.Details = _environment.IsDevelopment() 
                        ? exception.Message 
                        : "An internal server error occurred. Please try again later.";
                    response.StatusCode = (int)HttpStatusCode.InternalServerError;
                    break;
            }

            // Log additional details in development
            if (_environment.IsDevelopment())
            {
                _logger.LogError(exception, "Exception details: {StackTrace}", exception.StackTrace);
            }

            var options = new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                WriteIndented = _environment.IsDevelopment()
            };

            var jsonResponse = JsonSerializer.Serialize(errorResponse, options);
            await response.WriteAsync(jsonResponse);
        }
    }
}

