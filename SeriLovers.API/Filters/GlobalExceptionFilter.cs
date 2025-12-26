using System;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace SeriLovers.API.Filters
{
    public class GlobalExceptionFilter : IExceptionFilter
    {
        private readonly ILogger<GlobalExceptionFilter> _logger;

        public GlobalExceptionFilter(ILogger<GlobalExceptionFilter> logger)
        {
            _logger = logger;
        }

        public void OnException(ExceptionContext context)
        {
            var exception = context.Exception;
            _logger.LogError(exception, "Unhandled exception occurred: {Message}\n{StackTrace}", exception.Message, exception.StackTrace);

            // Include inner exception details if available
            var innerExceptionMessage = exception.InnerException != null 
                ? $" Inner Exception: {exception.InnerException.Message}" 
                : string.Empty;

            var response = new
            {
                statusCode = StatusCodes.Status500InternalServerError,
                message = $"An unexpected error occurred: {exception.Message}{innerExceptionMessage}",
                timestamp = DateTime.UtcNow,
                // Include stack trace in development
                stackTrace = context.HttpContext.RequestServices.GetService(typeof(IWebHostEnvironment)) is IWebHostEnvironment env && env.IsDevelopment()
                    ? exception.StackTrace
                    : null
            };

            context.Result = new ObjectResult(response)
            {
                StatusCode = StatusCodes.Status500InternalServerError
            };

            context.ExceptionHandled = true;
        }
    }
}
