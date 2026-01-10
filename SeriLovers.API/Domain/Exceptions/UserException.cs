namespace SeriLovers.API.Domain.Exceptions
{
    /// <summary>
    /// Exception thrown for user-facing errors that should be displayed to the user
    /// </summary>
    public class UserException : Exception
    {
        public UserException(string message) : base(message)
        {
        }

        public UserException(string message, Exception innerException) : base(message, innerException)
        {
        }
    }
}

