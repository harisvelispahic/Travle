using Travle.Model.Responses;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Travle.Services.Reports.Documents
{
    /// <summary>
    /// The printable "most popular destinations by period" report: a branded header with the reporting
    /// period, then a ranked table of destinations by bookings (with travelers / views / favorites for
    /// context). Composed from the same <see cref="PopularDestinationsReport"/> the on-screen preview uses.
    /// </summary>
    internal sealed class PopularDestinationsDocument : IDocument
    {
        private readonly PopularDestinationsReport _report;

        public PopularDestinationsDocument(PopularDestinationsReport report)
        {
            _report = report;
        }

        public void Compose(IDocumentContainer container)
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(28);
                page.DefaultTextStyle(style => style.FontSize(10).FontColor(ReportPdfTheme.ForestDark));

                var subtitle = $"Period: {ReportPdfTheme.FormatPeriod(_report.FromDate, _report.ToDate)}";
                if (!string.IsNullOrWhiteSpace(_report.CategoryName))
                {
                    subtitle += $"   ·   Category: {_report.CategoryName}";
                }

                page.Header().Element(c =>
                    ReportPdfTheme.ComposeHeader(c, "Most Popular Destinations", subtitle));
                page.Content().PaddingTop(14).Element(ComposeTable);
                page.Footer().Element(ReportPdfTheme.ComposeFooter);
            });
        }

        private void ComposeTable(IContainer container)
        {
            if (_report.Rows.Count == 0)
            {
                container.PaddingTop(40).AlignCenter().Text("No bookings in the selected period.")
                    .FontSize(11).FontColor(ReportPdfTheme.Muted);
                return;
            }

            container.Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.ConstantColumn(28);   // rank
                    columns.RelativeColumn(3);     // destination
                    columns.RelativeColumn(2);     // category
                    columns.RelativeColumn(2);     // region
                    columns.ConstantColumn(58);    // bookings
                    columns.ConstantColumn(58);    // travelers
                    columns.ConstantColumn(48);    // views
                    columns.ConstantColumn(58);    // favorites
                });

                table.Header(header =>
                {
                    HeaderText(header.Cell(), "#");
                    HeaderText(header.Cell(), "Destination");
                    HeaderText(header.Cell(), "Category");
                    HeaderText(header.Cell(), "Region");
                    HeaderText(header.Cell(), "Bookings", right: true);
                    HeaderText(header.Cell(), "Travelers", right: true);
                    HeaderText(header.Cell(), "Views", right: true);
                    HeaderText(header.Cell(), "Favorites", right: true);
                });

                var striped = false;
                foreach (var row in _report.Rows)
                {
                    BodyText(table.Cell(), row.Rank.ToString(), striped);
                    BodyText(table.Cell(), row.DestinationName, striped, bold: true);
                    BodyText(table.Cell(), row.CategoryName, striped);
                    BodyText(table.Cell(), row.RegionName, striped);
                    BodyText(table.Cell(), row.Bookings.ToString(), striped, right: true);
                    BodyText(table.Cell(), row.Travelers.ToString(), striped, right: true);
                    BodyText(table.Cell(), row.Views.ToString(), striped, right: true);
                    BodyText(table.Cell(), row.Favorites.ToString(), striped, right: true);
                    striped = !striped;
                }
            });
        }

        private static void HeaderText(IContainer cell, string text, bool right = false)
        {
            var container = ReportPdfTheme.HeaderCell(cell);
            if (right)
            {
                container = container.AlignRight();
            }
            container.Text(text).FontColor(Colors.White).Bold().FontSize(9);
        }

        private static void BodyText(IContainer cell, string text, bool striped, bool right = false, bool bold = false)
        {
            var container = ReportPdfTheme.BodyCell(cell, striped);
            if (right)
            {
                container = container.AlignRight();
            }
            var span = container.Text(text);
            if (bold)
            {
                span.Bold();
            }
        }

        public DocumentMetadata GetMetadata() => new() { Title = "Travle — Most Popular Destinations" };
    }
}
