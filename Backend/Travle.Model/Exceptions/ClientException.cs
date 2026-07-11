namespace Travle.Model.Exceptions
{
    /// <summary>
    /// User-facing business rule violation. The WebAPI <c>ExceptionFilter</c> maps this to HTTP 400
    /// with a JSON body: <c>{ "message": "...", "errors": { "clientError": ["..."] } }</c> for clients.
    /// </summary>
    public class ClientException : Exception
    {
        public ClientException(string message) : base(message)
        {
        }

        public ClientException(string message, Exception inner) : base(message, inner)
        {
        }
    }
}
