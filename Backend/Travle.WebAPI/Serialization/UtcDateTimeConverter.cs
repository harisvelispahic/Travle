using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Travle.WebAPI.Serialization
{
    /// <summary>
    /// Serializes every <see cref="DateTime"/> as a UTC instant with an explicit <c>Z</c> marker, whatever
    /// its <see cref="DateTimeKind"/>. SQL Server <c>datetime2</c> columns don't persist Kind, so values
    /// read back from the database arrive as <see cref="DateTimeKind.Unspecified"/> and would otherwise
    /// serialize without any zone marker — forcing the client to guess (and historically driving the
    /// Flutter <c>asUtc</c> reinterpretation). Travle stores every timestamp as UTC, so Unspecified is
    /// treated as UTC here; the wire is then unambiguous and <c>DateTime.parse</c> yields a true UTC value.
    /// Registered on both the MVC JSON options and the SignalR JSON protocol. Also covers
    /// <see cref="Nullable{DateTime}"/> via System.Text.Json's built-in nullable handling.
    /// See docs/time-and-timezones.md.
    /// </summary>
    public sealed class UtcDateTimeConverter : JsonConverter<DateTime>
    {
        // Millisecond precision is plenty for Travle (and Dart's DateTime.parse handles it cleanly).
        private const string Format = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'";

        public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
            => ToUtc(reader.GetDateTime());

        public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
            => writer.WriteStringValue(ToUtc(value).ToString(Format, CultureInfo.InvariantCulture));

        private static DateTime ToUtc(DateTime value) => value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
        };
    }
}
