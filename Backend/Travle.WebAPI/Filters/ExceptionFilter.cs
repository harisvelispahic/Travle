using Travle.Model.Exceptions;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using System.Net;

namespace Travle.WebAPI.Filters
{
    public class ExceptionFilter : ExceptionFilterAttribute
    {
        private readonly ILogger<ExceptionFilter> _logger;

        public ExceptionFilter(ILogger<ExceptionFilter> logger)
        {
            _logger = logger;
        }

        public override void OnException(ExceptionContext context)
        {
            // FluentValidation exceptions should be converted into model state errors
            if (context.Exception is FluentValidation.ValidationException fvEx)
            {
                foreach (var error in fvEx.Errors)
                {
                    // use property name (empty string for general errors) to key the message
                    context.ModelState.AddModelError(error.PropertyName ?? string.Empty, error.ErrorMessage);
                }

                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.BadRequest;
                _logger.LogWarning(context.Exception, "Validation failed for request.");
            }
            else if (context.Exception is ClientException ce)
            {
                context.ModelState.AddModelError("clientError", ce.Message);
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.BadRequest;
                _logger.LogWarning("Client rule: {Message}", ce.Message);
            }
            else
            {
                //context.ModelState.AddModelError("serverError", context.Exception.Message);
                context.ModelState.AddModelError("serverError", "Server side error, please check logs.");
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
                _logger.LogError(context.Exception, "Unhandled exception.");
            }

            var list = context.ModelState
                .Where(c => c.Value is { Errors.Count: > 0 })
                .ToDictionary(
                    c => c.Key,
                    c => c.Value!.Errors.Select(z => z.ErrorMessage).ToList());

            // Single human-readable line for mobile/clients; "clientError" is used for ClinetException.
            var allMessages = list.Values.SelectMany(v => v).Where(m => !string.IsNullOrWhiteSpace(m)).ToList();
            var message = allMessages.FirstOrDefault()
                ?? (context.Exception is ClientException ? context.Exception.Message : null)
                ?? "Request could not be processed.";

            context.Result = new JsonResult(new
            {
                message,
                errors = list
            });
        }
    }
}
