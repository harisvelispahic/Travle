using Travle.Model.Messaging;
using Travle.Worker.Email;

var builder = Host.CreateApplicationBuilder(args);

// RabbitMQ connection settings (env in compose, localhost in appsettings for local runs).
builder.Services.AddOptions<RabbitMqOptions>()
    .Bind(builder.Configuration.GetSection(RabbitMqOptions.SectionName))
    .ValidateOnStart();

// SMTP settings are NOT validated on start: the worker must still come up and drain the queue even
// when mail isn't configured yet (the sender logs and skips in that case).
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName));

builder.Services.AddSingleton<IEmailSender, MailKitEmailSender>();
builder.Services.AddHostedService<EmailConsumer>();

var host = builder.Build();
host.Run();
