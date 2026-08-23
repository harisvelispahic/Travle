namespace Travle.Model.Configuration
{
    /// <summary>
    /// Bridges the plain <c>.env</c> variable names onto the <c>Section__Key</c> names that .NET
    /// configuration binds, so every secret is written <b>once</b>.
    ///
    /// <para>The two naming styles exist for two different readers. <c>docker compose</c> reads
    /// <c>.env</c> only to interpolate <c>${VAR}</c> inside <c>docker-compose.yml</c>, which is why the
    /// plain names (<c>STRIPE_SECRET_KEY</c>) must exist; compose then injects the value into the
    /// container under the configuration name (<c>Payments__StripeSecretKey</c>). A local
    /// <c>dotnet run</c> has no compose: DotNetEnv loads the whole file into the process environment and
    /// configuration binds only the <c>Section__Key</c> names, so the plain ones mean nothing to it.
    /// Before this class, that forced every secret to be pasted twice under two names — and they drifted
    /// (the SMTP credentials were out of sync for weeks, so local runs mailed through a stale inbox).</para>
    ///
    /// <para>Only values that are <b>identical</b> in both environments are aliased. Anything that
    /// genuinely differs by host — the connection string (<c>localhost,1435</c> vs the
    /// <c>travle-sqlserver</c> service name) and the RabbitMQ host — is deliberately absent, and stays an
    /// explicit local override in <c>.env</c>. Aliasing those would let a local run silently inherit a
    /// container-only hostname it cannot resolve. Nothing infrastructural lives in
    /// <c>appsettings.json</c> any more (course §3.3 names RabbitMQ and SMTP explicitly): the
    /// last-resort fallbacks are the option classes' own property defaults.</para>
    ///
    /// <para>Lives in Travle.Model because both hosts need it and the worker references only this project
    /// (like <see cref="Messaging.RabbitMqOptions"/>). Call it after loading <c>.env</c> and before the
    /// host builder is created — the environment-variable configuration provider reads the environment
    /// as the builder is constructed.</para>
    /// </summary>
    public static class EnvironmentConfigurationAliases
    {
        /// <summary>
        /// Plain <c>.env</c> name → the configuration key it feeds. Keep in step with the
        /// <c>environment:</c> blocks in docker-compose.yml, which express the same mapping for containers.
        /// </summary>
        private static readonly (string PlainName, string ConfigurationKey)[] Aliases =
        [
            ("JWT_SECRET_KEY", "JwtToken__SecretKey"),
            ("JWT_ISSUER", "JwtToken__Issuer"),
            ("JWT_AUDIENCE", "JwtToken__Audience"),
            ("JWT_DURATION_MINUTES", "JwtToken__DurationInMinutes"),
            ("JWT_REFRESH_TOKEN_DAYS", "JwtToken__RefreshTokenDays"),

            // RabbitMQ: everything except the HOST, which genuinely differs per host (the compose
            // service name vs localhost) and stays an explicit local override in .env.
            ("RABBITMQ_PORT", "RabbitMq__Port"),
            ("RABBITMQ_USERNAME", "RabbitMq__Username"),
            ("RABBITMQ_PASSWORD", "RabbitMq__Password"),

            ("PLATFORM_TIMEZONE", "Time__PlatformTimeZoneId"),

            ("SMTP_HOST", "Smtp__Host"),
            ("SMTP_PORT", "Smtp__Port"),
            ("SMTP_USERNAME", "Smtp__Username"),
            ("SMTP_PASSWORD", "Smtp__Password"),
            ("SMTP_FROM", "Smtp__From"),
            ("SMTP_FROM_NAME", "Smtp__FromName"),
            ("SMTP_USE_STARTTLS", "Smtp__UseStartTls"),

            ("STRIPE_SECRET_KEY", "Payments__StripeSecretKey"),
            ("STRIPE_PUBLISHABLE_KEY", "Payments__StripePublishableKey"),
            ("STRIPE_WEBHOOK_SECRET", "Payments__StripeWebhookSecret"),
            ("PLATFORM_FEE_PERCENTAGE", "Payments__PlatformFeePercentage")
        ];

        /// <summary>
        /// Copies each plain variable onto its configuration key when that key has no value yet. An
        /// existing configuration key always wins — compose sets them directly, so a container is never
        /// affected by this method, and an explicit local override still beats the plain default.
        /// </summary>
        public static void Apply()
        {
            foreach (var (plainName, configurationKey) in Aliases)
            {
                if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(configurationKey)))
                {
                    continue;
                }

                var value = Environment.GetEnvironmentVariable(plainName);
                if (!string.IsNullOrWhiteSpace(value))
                {
                    Environment.SetEnvironmentVariable(configurationKey, value);
                }
            }
        }
    }
}
