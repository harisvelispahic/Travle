using Travle.Services;
using Travle.Services.Notifications;
using Travle.WebAPI.Options;
using Microsoft.Extensions.Options;

namespace Travle.WebAPI.Services;

/// <summary>
/// In-process lifecycle scheduler for bookings. On a fixed cadence it expires PaymentInProgress holds that
/// have passed their 15-minute window (releasing the held seats), auto-completes Confirmed bookings whose
/// schedule has ended, and raises the 24-hour pre-tour reminder — all driven through the centralized
/// booking state machine / booking service. Each tick runs in a fresh DI scope (its own DbContext); after
/// the work, it flushes that scope's notification dispatcher so any notification staged during the sweep
/// (expiry, auto-complete, reminder) is pushed over SignalR and emailed. A failed tick is logged and
/// swallowed so the loop never dies. Runs in the API process, not the RabbitMQ worker container.
/// </summary>
public class BookingLifecycleWorker : BackgroundService
{
    // The 15-minute hold and the schedule end time are the business deadlines; this is only how often we
    // check them. A minute is well within tolerance for a 15-minute hold and a 24-hour reminder window.
    private static readonly TimeSpan TickInterval = TimeSpan.FromMinutes(1);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly BookingReminderOptions _reminderOptions;
    private readonly ILogger<BookingLifecycleWorker> _logger;

    public BookingLifecycleWorker(
        IServiceScopeFactory scopeFactory,
        IOptions<BookingReminderOptions> reminderOptions,
        ILogger<BookingLifecycleWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _reminderOptions = reminderOptions.Value;
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
            var reminded = await bookings.SendDueRemindersAsync(_reminderOptions.WindowHours, stoppingToken);

            // Deliver everything the sweep staged (expiry / completion / reminder notifications) now that the
            // rows have committed. This scope's dispatcher is the same instance the sweep enqueued into.
            await scope.ServiceProvider.GetRequiredService<INotificationDispatcher>().FlushAsync(stoppingToken);

            if (expired > 0 || completed > 0 || reminded > 0)
            {
                _logger.LogInformation(
                    "Booking lifecycle sweep: expired {Expired} hold(s), completed {Completed} booking(s), reminded {Reminded} booking(s).",
                    expired, completed, reminded);
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
