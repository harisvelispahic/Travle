# Password reset + email pipeline — code walkthrough

> A personal explainer (not part of the graded docs) — companion to
> `email-pipeline.md`. That file explains the *architecture*; this one walks the
> *actual code* block by block, following a message's journey **produce → queue → consume → send**.
> Move/keep/delete it as you like.

The mental model every file below is one box of:

```
  API                          RabbitMQ                    Worker
 ┌─────────────────────┐      ┌──────────────┐          ┌──────────────────────┐
 │ PasswordResetService│      │ travle.emails│          │ EmailConsumer        │
 │   → IEmailPublisher │ ───▶ │  (durable    │  ──────▶ │   → dispatch by type │
 │       (publish)     │      │   queue)     │          │   → MailKitEmailSender│──▶ SMTP
 └─────────────────────┘      └──────────────┘          └──────────────────────┘
```

---

## Part 1 — The shared vocabulary (`Travle.Model/Messaging`)

The API and worker are separate programs. The only things they must *agree* on are the queue name,
the message shape, and the connection settings. Those live in `Travle.Model` because both projects
reference it.

### `RabbitMqOptions.cs`
```csharp
public sealed class RabbitMqOptions
{
    public const string SectionName = "RabbitMq";
    [Required] public string Host { get; set; } = "localhost";
    [Range(1, 65535)] public int Port { get; set; } = 5672;
    [Required] public string Username { get; set; } = "guest";
    [Required] public string Password { get; set; } = "guest";
}
```
- A typed bag of connection settings. `SectionName = "RabbitMq"` is the config section it binds from
  (`RabbitMq:Host`, or the env var `RabbitMq__Host`).
- **Port 5672** is RabbitMQ's AMQP port (the protocol clients speak). 15672 is the management web UI —
  a different thing.
- The defaults (`localhost`, `guest/guest`) are what a local RabbitMQ uses out of the box, so local
  runs need no config. In Docker, compose overrides `Host` with the service name `travle-rabbitmq`.

### `MessagingConstants.cs`
```csharp
public const string EmailQueue = "travle.emails";
public const string TypeHeader = "type";
public static class EmailType { public const string PasswordReset = "password-reset"; }
```
- `EmailQueue` — the single named mailbox all emails flow through. One queue for all email types keeps
  the plumbing simple.
- `TypeHeader` / `EmailType.PasswordReset` — a message carries a header called `type` whose value says
  *which kind* of email it is. The worker reads it to decide how to render. Adding "booking confirmed"
  later = a new constant here + a new `case` in the worker. No new queue, no new plumbing.

### `PasswordResetEmailMessage.cs`
```csharp
public sealed record PasswordResetEmailMessage
{
    public required string ToEmail { get; init; }
    public required string ToName { get; init; }
    public required string Code { get; init; }
    public required DateTime ExpiresAtUtc { get; init; }
}
```
- The **payload**: exactly the data the worker needs to write the email. A `record` because it's
  immutable data-in-transit.
- `Code` is the **plaintext** 6-digit code. This is the one place the plaintext exists besides the
  email itself — the database only holds its hash. The message lives for milliseconds, then it's gone.

---

## Part 2 — The API produces the message

### `RabbitMqConnection.cs` — the single shared connection

The most important RabbitMQ concept. Two layers:
- A **connection** = a real TCP socket to the broker. Expensive to open → **one per process**, held
  open for the app's lifetime (course §A.1 — never one per publish).
- A **channel** (`IChannel`) = a lightweight virtual session *inside* that one connection. Cheap. Not
  thread-safe. Created per unit of work and thrown away.

```csharp
public async Task<IConnection> GetConnectionAsync(CancellationToken ct = default)
{
    if (_connection is { IsOpen: true }) return _connection;      // fast path: reuse

    await _gate.WaitAsync(ct);                                    // only one thread builds it
    try
    {
        if (_connection is { IsOpen: true }) return _connection;  // double-check after the lock
        if (_connection is not null) { await _connection.DisposeAsync(); _connection = null; }

        var factory = new ConnectionFactory { HostName = _options.Host, Port = _options.Port,
                                              UserName = _options.Username, Password = _options.Password };
        _connection = await factory.CreateConnectionAsync(ct);    // opens the TCP connection
        return _connection;
    }
    finally { _gate.Release(); }
}
```
- Registered as a **singleton**, so the whole API shares this object → one connection.
- The `SemaphoreSlim _gate` is a lock: if two requests need the connection at the same moment on first
  use, only one creates it; the other waits and then sees it's already built (the "double-check" `if`).
  Classic thread-safe lazy-init.
- The `IsOpen` check means if the connection ever drops (broker restart), the next call rebuilds it.
- `ConnectionFactory` is RabbitMQ.Client's builder; `CreateConnectionAsync` is the async open
  (RabbitMQ.Client 7.x is fully async — no blocking calls, satisfying §P).

### `RabbitMqEmailPublisher.cs` — putting a message on the queue
```csharp
public Task PublishPasswordResetAsync(PasswordResetEmailMessage message, CancellationToken ct = default)
    => PublishAsync(MessagingConstants.EmailType.PasswordReset, message, ct);

private async Task PublishAsync<T>(string type, T message, CancellationToken ct)
{
    var connection = await _connection.GetConnectionAsync(ct);
    await using var channel = await connection.CreateChannelAsync(cancellationToken: ct);   // cheap, disposable

    await channel.QueueDeclareAsync(
        queue: MessagingConstants.EmailQueue,
        durable: true, exclusive: false, autoDelete: false, cancellationToken: ct);

    var body = JsonSerializer.SerializeToUtf8Bytes(message);
    var properties = new BasicProperties
    {
        Persistent = true,
        ContentType = "application/json",
        Headers = new Dictionary<string, object?> { [MessagingConstants.TypeHeader] = type }
    };

    await channel.BasicPublishAsync(
        exchange: string.Empty, routingKey: MessagingConstants.EmailQueue,
        mandatory: false, basicProperties: properties, body: body, cancellationToken: ct);
}
```
Block by block:
- `await using var channel = ...` — grab a fresh channel from the shared connection; `await using`
  disposes it the moment we're done. One channel per publish.
- `QueueDeclareAsync(... durable: true ...)` — **declare the queue**. Declaring is *idempotent*: "make
  sure a queue named `travle.emails` exists; if it already does, fine." Both publisher and consumer
  declare it, so whoever starts first creates it. The flags:
  - `durable: true` → the queue definition survives a broker restart.
  - `exclusive: false` → not tied to this one connection.
  - `autoDelete: false` → don't delete it when the last consumer disconnects.
- `SerializeToUtf8Bytes(message)` — messages travel as raw **bytes**, so we JSON-serialize the record
  to a UTF-8 byte array.
- `BasicProperties` = metadata attached to the message:
  - `Persistent = true` → the broker writes the message **to disk** (durable queue + persistent message
    = the message isn't lost if RabbitMQ bounces while it's queued).
  - `Headers["type"] = "password-reset"` → our discriminator. **Gotcha:** RabbitMQ transmits string
    header values as raw byte arrays, which is why the worker decodes it with `Encoding.UTF8.GetString`.
- `BasicPublishAsync(exchange: "", routingKey: EmailQueue, ...)` — the actual send:
  - An **exchange** is RabbitMQ's router — publishers send to an *exchange*, which decides which
    queue(s) get the message.
  - `exchange: ""` is the **default exchange**, a built-in one whose rule is: route to the queue whose
    name equals the **routing key**. So `exchange: "", routingKey: "travle.emails"` = "drop this
    straight into the `travle.emails` queue." Simplest routing, perfect for one queue. (A named exchange
    would let one event fan out to several queues.)
  - `mandatory: false` → if no queue matches, silently drop.

### `PasswordResetService.cs` — the reset logic (and its security)

**Request side:**
```csharp
var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Email == request.Email, ct);
if (user is null || user.IsSuspended) { _logger.LogInformation(...); return; }   // silent no-op
```
- **Anti-enumeration**: if the email isn't registered (or the user is suspended), return *normally and
  do nothing*. The controller sends the same 200 either way, so an attacker can't tell registered
  emails from unregistered ones by poking this endpoint.

```csharp
_dbContext.PasswordResetCodes.RemoveRange(
    _dbContext.PasswordResetCodes.Where(c => c.UserId == user.Id && c.UsedAt == null));

var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
var salt = _cryptoService.GenerateSalt();
var resetCode = new PasswordResetCode
{
    UserId = user.Id,
    CodeHash = $"{salt}:{_cryptoService.GenerateHash(code, salt)}",   // "salt:hash"
    ExpiresAt = DateTime.UtcNow.AddMinutes(CodeLifetimeMinutes)       // 15 min
};
_dbContext.PasswordResetCodes.Add(resetCode);
await _dbContext.SaveChangesAsync(ct);
```
- `RemoveRange(... UsedAt == null)` → invalidate any older unused code, so there's only **one live
  code** per user at a time.
- `RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6")` → a cryptographically-random 6-digit
  code (`"D6"` zero-pads, so `42` → `"000042"`). `RandomNumberGenerator`, never `System.Random` (§A.3).
- `CodeHash = $"{salt}:{hash}"` → we store the code **hashed, exactly like a password** (PBKDF2 via the
  same `CryptoService`). The salt sits right next to the hash in one column (`salt:hash`) — a common
  pattern that avoided a schema change. Base64 never contains `:`, so splitting later is safe. A DB leak
  reveals only useless hashes, and brute-force is pointless because the code dies in 15 minutes.

```csharp
await _emailPublisher.PublishPasswordResetAsync(new PasswordResetEmailMessage {
    ToEmail = user.Email, ToName = user.FirstName, Code = code, ExpiresAtUtc = resetCode.ExpiresAt }, ct);
```
- Only after the code is safely persisted do we hand the **plaintext** to the queue for the worker.

**Reset side:**
```csharp
var resetCode = await _dbContext.PasswordResetCodes
    .Where(c => c.UserId == user.Id && c.UsedAt == null && c.ExpiresAt > now)
    .OrderByDescending(c => c.CreatedAt).FirstOrDefaultAsync();

if (resetCode is null || !CodeMatches(resetCode.CodeHash, request.Code))
    throw new BusinessRuleException(GenericFailure);

user.PasswordSalt = _cryptoService.GenerateSalt();
user.PasswordHash = _cryptoService.GenerateHash(request.NewPassword, user.PasswordSalt);
resetCode.UsedAt = now;                                                    // single-use
_dbContext.RefreshTokens.RemoveRange(_dbContext.RefreshTokens.Where(rt => rt.UserId == user.Id)); // log out everywhere
await _dbContext.SaveChangesAsync();
```
- Finds the newest **unused, unexpired** code; `CodeMatches` splits `salt:hash` and runs
  `CryptoService.Verify`.
- Every failure path (unknown email, no code, wrong code, expired) throws the *same* `GenericFailure`
  message — no signal for guessing.
- On success: set the new password, mark the code `UsedAt` (no replay), and **delete all refresh
  tokens** — a reset ends every session. All in one `SaveChangesAsync` = one transaction.

The **DTOs** (`ForgotPasswordRequest`, `ResetPasswordRequest`) are plain input bags; the **validators**
enforce format (`Matches(@"^\d{6}$")` for the code, min-length for the new password, confirm-equals).

### `AccessController` endpoints
```csharp
[AllowAnonymous][HttpPost("ForgotPassword")]
public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request, CancellationToken ct)
{
    await _passwordResetService.RequestResetAsync(request, ct);
    return Ok(new { message = "If an account exists for that email, a reset code has been sent." });
}
```
- `[AllowAnonymous]` because someone who forgot their password isn't logged in.
- The response is deliberately vague ("**if** an account exists") — the anti-enumeration promise made
  good at the HTTP layer.

---

## Part 3 — The worker consumes and sends

### `SmtpOptions.cs`
```csharp
public string Host { get; set; } = string.Empty;
public int Port { get; set; } = 587;              // 587 = STARTTLS
public bool UseStartTls { get; set; } = true;
// ... Username, Password, From, FromName
```
- SMTP settings, held **only by the worker** (the API never touches SMTP). Deliberately *not* validated
  on startup so the worker still boots and drains the queue when mail isn't configured — an empty `Host`
  just means "skip sending."

### `EmailConsumer.cs` — the heart of the worker

A `BackgroundService`: `ExecuteAsync` runs once at startup and lives for the app's lifetime.

```csharp
_connection = await ConnectWithRetryAsync(stoppingToken);
_channel = await _connection.CreateChannelAsync(cancellationToken: stoppingToken);
await _channel.QueueDeclareAsync(EmailQueue, durable: true, exclusive: false, autoDelete: false, ...);
await _channel.BasicQosAsync(prefetchSize: 0, prefetchCount: 5, global: false, ...);
```
- `ConnectWithRetryAsync` — **why retry?** In `docker compose up`, the worker often starts *before*
  RabbitMQ is ready. Without retry it would crash-loop. This keeps trying with growing backoff
  (1s, 2s, 4s… capped at 30s) until RabbitMQ answers.
- Same idempotent `QueueDeclareAsync` — the consumer also ensures the queue exists.
- `BasicQosAsync(prefetchCount: 5)` — **prefetch**: "give me at most 5 unacknowledged messages at a
  time." Flow control. Without it RabbitMQ shoves the whole queue at one consumer; with it, one slow
  email can't hog a batch, and work spreads if you run multiple workers.

```csharp
var consumer = new AsyncEventingBasicConsumer(_channel);
consumer.ReceivedAsync += OnMessageAsync;
await _channel.BasicConsumeAsync(EmailQueue, autoAck: false, consumer, ...);
```
- `AsyncEventingBasicConsumer` — the async consumer type the course requires (§A.1). You subscribe by
  adding a handler to `ReceivedAsync`; RabbitMQ pushes messages, firing `OnMessageAsync` per message.
- `autoAck: false` — **manual acknowledgement**, the critical reliability switch. With `autoAck: true`
  RabbitMQ deletes a message the instant it hands it over → a crash mid-send loses the email. With
  `false`, the message stays "unacknowledged" until *we* ack it; if the worker dies first, RabbitMQ
  redelivers. This is how "kill the worker mid-queue and lose nothing" works.

```csharp
try { await Task.Delay(Timeout.Infinite, stoppingToken); }
catch (OperationCanceledException) { }
```
- After wiring the subscription, `ExecuteAsync` has nothing left to *do* — messages arrive via the event
  callback. So we park here until shutdown (cancellation makes `Task.Delay` throw, which we swallow).

**Handling one message:**
```csharp
private async Task OnMessageAsync(object sender, BasicDeliverEventArgs eventArgs)
{
    try
    {
        await DispatchWithRetryAsync(eventArgs);
        await _channel!.BasicAckAsync(eventArgs.DeliveryTag, multiple: false);   // success → delete
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Giving up ... nacking without requeue.");
        await _channel!.BasicNackAsync(eventArgs.DeliveryTag, multiple: false, requeue: false); // give up
    }
}
```
- `DeliveryTag` is the per-message ID RabbitMQ uses to track ack/nack.
- **Ack** on success → RabbitMQ removes the message. `multiple: false` = "just this one."
- **Nack** after retries exhausted → `requeue: false` = *don't* put it back. A message that fails 4× is
  likely a poison message; requeuing would hot-loop. We drop it, having logged loudly (§A.1 — never die
  silently). Later hardening: point that at a *dead-letter queue* to keep the corpse.

**The retry/backoff:**
```csharp
private async Task DispatchWithRetryAsync(BasicDeliverEventArgs eventArgs)
{
    var delay = TimeSpan.FromSeconds(1);
    for (var attempt = 1; ; attempt++)
    {
        try { await DispatchAsync(eventArgs); return; }
        catch (Exception ex) when (attempt < MaxSendAttempts)     // 4
        {
            _logger.LogWarning(ex, "attempt {Attempt}/{Max} failed; retrying in {Sec}s.", ...);
            await Task.Delay(delay, _stoppingToken);
            delay = TimeSpan.FromSeconds(delay.TotalSeconds * 2);  // 1 → 2 → 4 → 8
        }
    }
}
```
- Transient failures (SMTP briefly unreachable, a blip) usually clear on retry. Up to 4 tries with
  **exponential backoff** — the exact §A.1 pattern.
- The `when (attempt < MaxSendAttempts)` filter is the trick: on the *last* attempt the exception is
  **not** caught here, so it propagates to `OnMessageAsync`'s catch → nack. Earlier attempts are caught
  → wait → loop.

**Dispatch by type + rendering:**
```csharp
var type = ReadTypeHeader(eventArgs);                     // "password-reset"
switch (type)
{
    case MessagingConstants.EmailType.PasswordReset:
        var message = JsonSerializer.Deserialize<PasswordResetEmailMessage>(eventArgs.Body.Span)
            ?? throw new InvalidOperationException("Empty password-reset payload.");
        await SendPasswordResetAsync(message);
        break;
    default:
        _logger.LogWarning("... unknown type '{Type}'; discarding.", type);
        break;   // unknown → no retry, just ack-drop
}
```
```csharp
private static string? ReadTypeHeader(BasicDeliverEventArgs eventArgs)
{
    if (eventArgs.BasicProperties.Headers is { } headers
        && headers.TryGetValue(MessagingConstants.TypeHeader, out var value)
        && value is byte[] bytes)
        return Encoding.UTF8.GetString(bytes);   // headers arrive as byte[]
    return null;
}
```
- `eventArgs.Body.Span` is the raw bytes we published; `Deserialize<PasswordResetEmailMessage>` turns
  them back into the record (normal project, so reflection-based JSON works here).
- `ReadTypeHeader` is where the earlier gotcha pays off: the `type` header set as a string comes back as
  a **`byte[]`**, so we UTF-8-decode it. That string drives the `switch`. New email types slot in as new
  `case`s — the whole receive/ack/retry machinery is reused untouched.

```csharp
private Task SendPasswordResetAsync(PasswordResetEmailMessage message)
{
    var minutes = Math.Max(1, (int)Math.Round((message.ExpiresAtUtc - DateTime.UtcNow).TotalMinutes));
    var subject = "Your Travle password reset code";
    var body = $"Hello {message.ToName},\n\nYour Travle password reset code is: {message.Code}\n\n...";
    return _emailSender.SendAsync(message.ToEmail, message.ToName, subject, body, _stoppingToken);
}
```
- The **template** for this email type: payload → subject + body. (Recomputing `minutes` from
  `ExpiresAtUtc` keeps the email honest even if it sat in the queue a while.)

### `MailKitEmailSender.cs` — the actual SMTP send
```csharp
if (string.IsNullOrWhiteSpace(_options.Host))
{
    _logger.LogWarning("SMTP host is not configured; email '{Subject}' to {To} was not sent.", ...);
    return;   // graceful skip — the line the round-trip test triggered
}

var message = new MimeMessage();
message.From.Add(new MailboxAddress(_options.FromName, _options.From));
message.To.Add(new MailboxAddress(toName, toEmail));
message.Subject = subject;
message.Body = new TextPart("plain") { Text = body };
```
- `MimeMessage` / `MailboxAddress` / `TextPart` are MailKit's email model (MIME = the standard email
  format). `TextPart("plain")` = plain-text body; `"html"` would be a rich one.

```csharp
var secureOption = _options.UseStartTls ? SecureSocketOptions.StartTls : SecureSocketOptions.SslOnConnect;
using var client = new SmtpClient();
await client.ConnectAsync(_options.Host, _options.Port, secureOption, cancellationToken);
if (!string.IsNullOrEmpty(_options.Username))
    await client.AuthenticateAsync(_options.Username, _options.Password ?? string.Empty, cancellationToken);
await client.SendAsync(message, cancellationToken);
await client.DisconnectAsync(quit: true, cancellationToken);
```
- `SecureSocketOptions` = how TLS is negotiated:
  - **StartTls** (port 587/2525, e.g. Mailtrap): connect in plaintext, then upgrade to encrypted.
  - **SslOnConnect** (port 465): encrypted from the very first byte.
- `ConnectAsync` → open the SMTP session; `AuthenticateAsync` → log in (skipped if no username, e.g. a
  local relay); `SendAsync` → hand the message over; `DisconnectAsync(quit: true)` → politely close.
  `using var client` guarantees the socket is disposed even on error.

---

## Part 4 — Wiring (DI + config)

**API `Program.cs`:**
```csharp
builder.Services.AddOptions<RabbitMqOptions>().Bind(...).ValidateDataAnnotations().ValidateOnStart();
builder.Services.AddSingleton<RabbitMqConnection>();                    // one connection, whole app
builder.Services.AddSingleton<IEmailPublisher, RabbitMqEmailPublisher>();
builder.Services.AddScoped<IPasswordResetService, PasswordResetService>();
```
- `RabbitMqConnection` and the publisher are **singletons** (one shared connection). The reset service
  is **scoped** (per request, because it uses the `DbContext`). A singleton publisher injected into a
  scoped service is fine.

**Worker `Program.cs`:**
```csharp
builder.Services.AddOptions<RabbitMqOptions>().Bind(...).ValidateOnStart();
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName)); // not validated
builder.Services.AddSingleton<IEmailSender, MailKitEmailSender>();
builder.Services.AddHostedService<EmailConsumer>();   // the long-running consumer
```
- `AddHostedService<EmailConsumer>` makes the consumer start and run for the container's lifetime.
- SMTP is `Configure`d without validation on purpose (empty host is a valid "disabled" state). (The
  Worker SDK doesn't ship `ValidateDataAnnotations`, so it's dropped for RabbitMq here too.)

**`docker-compose.yml` + `.env`:**
- `RabbitMq__*` env now goes into **both** `travle-api` and `travle-worker` (before, only the worker had
  it — the API needs it now to publish).
- `Smtp__*` goes into the worker, with `:-` defaults (`${SMTP_PORT:-587}`) so a missing value can't
  produce an empty string that breaks int/bool binding.
- The double underscore `__` is ASP.NET's convention for nesting: `RabbitMq__Host` → the `RabbitMq:Host`
  config key. That's how a flat env var maps onto the `RabbitMqOptions` object.

---

## Part 5 — What the round-trip test proved

A throwaway publisher put a real message on `travle.emails`; the worker logged:
```
Email consumer is listening on 'travle.emails'.
SMTP host is not configured; email 'Your Travle password reset code' to roundtrip@example.com was not sent.
```
That single run exercised: connection → channel → queue declare → `AsyncEventingBasicConsumer` →
`ReceivedAsync` fired → `type` header decoded → JSON deserialized to the record → template rendered →
sender reached (and correctly skipped, since no SMTP). Everything but the final SMTP hop, which only
needs your Mailtrap creds.

---

### The one habit to carry forward
Every future email (booking confirmed, refund, role decision, reminders) is *the same pipeline* — you
only add: a message record in `Travle.Model/Messaging`, a `PublishXxxAsync` on the publisher, an
`EmailType` constant, and a `case` + template in the consumer. Connection, queue, ack/retry/backoff,
config — all reused.
