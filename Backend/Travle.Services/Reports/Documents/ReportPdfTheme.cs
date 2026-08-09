using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Travle.Services.Reports.Documents
{
    /// <summary>
    /// Shared look-and-feel for the generated PDF reports: the Travle forest-green palette (mirrors the
    /// desktop <c>TravleTokens</c>), value formatters, and the common branded header / footer so both
    /// reports read as one family. Kept in one place so the two documents never drift apart.
    /// </summary>
    internal static class ReportPdfTheme
    {
        public static readonly Color Forest = Color.FromHex("#235347");
        public static readonly Color ForestDark = Color.FromHex("#0B2B26");
        public static readonly Color Mint = Color.FromHex("#DAF1DD");
        public static readonly Color MintOutline = Color.FromHex("#C7DED0");
        public static readonly Color RowStripe = Color.FromHex("#F3F8F4");
        public static readonly Color Muted = Color.FromHex("#5B6B63");

        public static string FormatMoney(decimal amount) =>
            amount.ToString("N2", CultureInfo.InvariantCulture) + " KM";

        public static string FormatDate(DateTime value) =>
            value.ToString("dd MMM yyyy", CultureInfo.InvariantCulture);

        public static string FormatRating(double rating) =>
            rating <= 0 ? "—" : rating.ToString("0.0", CultureInfo.InvariantCulture);

        /// <summary>Human-readable period caption for a report header ("All time", a range, or one bound).</summary>
        public static string FormatPeriod(DateTime? from, DateTime? to)
        {
            if (from is null && to is null)
            {
                return "All time";
            }
            if (from is not null && to is not null)
            {
                return $"{FormatDate(from.Value)} – {FormatDate(to.Value)}";
            }
            return from is not null ? $"From {FormatDate(from.Value)}" : $"Up to {FormatDate(to!.Value)}";
        }

        /// <summary>Branded header band: the Travle wordmark, the report title, and a subtitle line.</summary>
        public static void ComposeHeader(IContainer container, string title, string subtitle)
        {
            container.Background(Forest).Padding(18).Row(row =>
            {
                row.RelativeItem().Column(column =>
                {
                    column.Item().Text("Travle").FontSize(11).FontColor(Mint).Bold().LetterSpacing(0.08f);
                    column.Item().PaddingTop(2).Text(title).FontSize(20).FontColor(Colors.White).Bold();
                    column.Item().PaddingTop(2).Text(subtitle).FontSize(10).FontColor(Mint);
                });
                row.ConstantItem(150).AlignRight().AlignBottom().Text(
                        $"Generated {FormatDate(DateTime.UtcNow)}")
                    .FontSize(9).FontColor(Mint);
            });
        }

        /// <summary>Page footer with a centred page-x-of-y counter.</summary>
        public static void ComposeFooter(IContainer container)
        {
            container.PaddingTop(8).Row(row =>
            {
                row.RelativeItem().Text("Travle administrative report").FontSize(8).FontColor(Muted);
                row.RelativeItem().AlignRight().Text(text =>
                {
                    text.DefaultTextStyle(style => style.FontSize(8).FontColor(Muted));
                    text.Span("Page ");
                    text.CurrentPageNumber();
                    text.Span(" of ");
                    text.TotalPages();
                });
            });
        }

        /// <summary>Styles a table header cell (forest band, white bold text).</summary>
        public static IContainer HeaderCell(IContainer container) =>
            container.Background(Forest).PaddingVertical(6).PaddingHorizontal(6);

        /// <summary>Styles a body cell with an optional zebra stripe.</summary>
        public static IContainer BodyCell(IContainer container, bool striped) =>
            (striped ? container.Background(RowStripe) : container)
                .BorderBottom(0.5f).BorderColor(MintOutline)
                .PaddingVertical(5).PaddingHorizontal(6);
    }
}
