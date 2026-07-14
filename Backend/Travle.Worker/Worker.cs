namespace Travle.Worker;

/// <summary>
/// Background host for the Travle worker container. RabbitMQ consumers are registered here in
/// Phase 9; for now it starts, logs once, and idles until shutdown so the container stays alive.
/// </summary>
public class Worker(ILogger<Worker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Travle.Worker started at {TimeUtc} UTC", DateTime.UtcNow);

        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException)
        {
            // Expected on graceful shutdown.
        }

        logger.LogInformation("Travle.Worker stopped at {TimeUtc} UTC", DateTime.UtcNow);
    }
}
