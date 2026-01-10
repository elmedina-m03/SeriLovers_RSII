namespace SeriLovers.API.Domain
{
    /// <summary>
    /// Represents the watching status of a series for a user
    /// </summary>
    public enum SeriesWatchingStatus
    {
        /// <summary>
        /// Series has not been started (no episodes watched)
        /// </summary>
        ToWatch = 0,

        /// <summary>
        /// Series is in progress (at least one episode watched, but not all)
        /// </summary>
        InProgress = 1,

        /// <summary>
        /// Series is finished (all episodes watched)
        /// </summary>
        Finished = 2
    }
}

