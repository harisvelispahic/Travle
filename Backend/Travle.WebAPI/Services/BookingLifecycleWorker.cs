using Travle.Services;

namespace Travle.WebAPI.Services;

/// <summary>
/// In-process lifecycle scheduler for bookings. On a fixed cadence it expires PaymentInProgress holds
/// that have passed their 15-minute window (releasing the held seats) and auto-completes Confirmed
/// bookings whose schedule has ended — both driven through the centralized booking state machine. Each
/// tick runs in a fresh DI scope (its own DbContext); a failed tick is logged and swallowed so the loop
/// never dies. Runs in the API process, not the RabbitMQ worker container (per the spec's process tree).
/// </summary>
public class BookingLifecycleWorker : BackgroundService
{
    // The 15-minute hold and the schedule end time are the business deadlines; this is only how often we
    // check them. A minute is well within tolerance for a 15-minute hold.
    private static readonly TimeSpan TickInterval = TimeSpan.FromMinutes(1);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<BookingLifecycleWorker> _logger;

    public BookingLifecycleWorker(IServiceScopeFactory scopeFactory, ILogger<BookingLifecycleWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TickInterval);

        // Sweep once at startup, then on every interval until shutdown.
        do
        {
            await RunTickAsync(stoppingToken);
        }
        while (await WaitForNextTickAsync(timer, stoppingToken));
    }

    private static async Task<bool> WaitForNextTickAsync(PeriodicTimer timer, CancellationToken stoppingToken)
    {
        try
        {
            return await timer.WaitForNextTickAsync(stoppingToken);
        }
        catch (OperationCanceledException)
        {
            return false;
        }
    }

    private async Task RunTickAsync(CancellationToken stoppingToken)
    {
        try
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var bookings = scope.ServiceProvider.GetRequiredService<IBookingService>();

            var expired = await bookings.ExpireOverdueHoldsAsync(stoppingToken);
            var completed = await bookings.AutoCompletePastConfirmedAsync(stoppingToken);

            if (expired > 0 || completed > 0)
            {
                _logger.LogInformation(
                    "Booking lifecycle sweep: expired {Expired} hold(s), completed {Completed} booking(s).",
                    expired, completed);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Host is shutting down — expected, stop quietly.
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Booking lifecycle sweep failed; will retry on the next interval.");
        }
    }
}
