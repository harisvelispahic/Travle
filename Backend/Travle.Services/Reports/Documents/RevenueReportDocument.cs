using Travle.Model.Responses;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Travle.Services.Reports.Documents
{
    /// <summary>
    /// The printable "revenue by category / region" report: a branded header, a grand-totals strip, then
    /// two single-GroupBy tables (by category, by region) whose rows reconcile exactly to the totals.
    /// Revenue is attributed to each tour's primary destination. Composed from the same
    /// <see cref="RevenueReport"/> the on-screen preview uses.
    /// </summary>
    internal sealed class RevenueReportDocument : IDocument
    {
        private readonly RevenueReport _report;

        public RevenueReportDocument(RevenueReport report)
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

                page.Header().Element(c => ReportPdfTheme.ComposeHeader(
                    c, "Revenue by Category & Region",
                    $"Period: {ReportPdfTheme.FormatPeriod(_report.FromDate, _report.ToDate)}"));

                page.Content().PaddingTop(14).Column(column =>
                {
                    column.Spacing(16);
                    column.Item().Element(ComposeTotals);
                    column.Item().Element(c => ComposeSection(c, "By Category", _report.ByCategory));
                    column.Item().Element(c => ComposeSection(c, "By Region", _report.ByRegion));
                });

                page.Footer().Element(ReportPdfTheme.ComposeFooter);
            });
        }

        private void ComposeTotals(IContainer container)
        {
            container.Row(row =>
            {
                row.Spacing(10);
                row.RelativeItem().Element(c => TotalBox(c, "Gross captured", _report.TotalGross));
                row.RelativeItem().Element(c => TotalBox(c, "Refunded", _report.TotalRefunded));
                row.RelativeItem().Element(c => TotalBox(c, "Net revenue", _report.TotalNet, emphasize: true));
            });
        }

        private static void TotalBox(IContainer container, string label, decimal value, bool emphasize = false)
        {
            container
                .Background(emphasize ? ReportPdfTheme.Forest : ReportPdfTheme.Mint)
                .Border(0.5f).BorderColor(ReportPdfTheme.MintOutline)
                .Padding(10)
                .Column(column =>
                {
                    column.Item().Text(label).FontSize(9)
                        .FontColor(emphasize ? ReportPdfTheme.Mint : ReportPdfTheme.Muted);
                    column.Item().PaddingTop(2).Text(ReportPdfTheme.FormatMoney(value))
                        .FontSize(14).Bold()
                        .FontColor(emphasize ? Colors.White : ReportPdfTheme.ForestDark);
                });
        }

        private void ComposeSection(IContainer container, string heading, List<RevenueGroupRow> rows)
        {
            container.Column(column =>
            {
                column.Item().PaddingBottom(6).Text(heading).FontSize(13).Bold()
                    .FontColor(ReportPdfTheme.Forest);

                if (rows.Count == 0)
                {
                    column.Item().Text("No revenue in the selected period.")
                        .FontSize(10).FontColor(ReportPdfTheme.Muted);
                    return;
                }

                column.Item().Table(table =>
                {
                    table.ColumnsDefinition(columns =>
                    {
                        columns.RelativeColumn(3);   // group name
                        columns.ConstantColumn(64);  // bookings
                        columns.ConstantColumn(90);  // gross
                        columns.ConstantColumn(90);  // refunded
                        columns.ConstantColumn(90);  // net
                    });

                    table.Header(header =>
                    {
                        HeaderText(header.Cell(), heading.Replace("By ", string.Empty));
                        HeaderText(header.Cell(), "Bookings", right: true);
                        HeaderText(header.Cell(), "Gross", right: true);
                        HeaderText(header.Cell(), "Refunded", right: true);
                        HeaderText(header.Cell(), "Net", right: true);
                    });

                    var striped = false;
                    foreach (var row in rows)
                    {
                        BodyText(table.Cell(), row.GroupName, striped, bold: true);
                        BodyText(table.Cell(), row.Bookings.ToString(), striped, right: true);
                        BodyText(table.Cell(), ReportPdfTheme.FormatMoney(row.GrossRevenue), striped, right: true);
                        BodyText(table.Cell(), ReportPdfTheme.FormatMoney(row.Refunded), striped, right: true);
                        BodyText(table.Cell(), ReportPdfTheme.FormatMoney(row.NetRevenue), striped, right: true);
                        striped = !striped;
                    }

                    // Section total row (reconciles to the grand totals above).
                    TotalCell(table.Cell(), "Total");
                    TotalCell(table.Cell(), rows.Sum(r => r.Bookings).ToString(), right: true);
                    TotalCell(table.Cell(), ReportPdfTheme.FormatMoney(rows.Sum(r => r.GrossRevenue)), right: true);
                    TotalCell(table.Cell(), ReportPdfTheme.FormatMoney(rows.Sum(r => r.Refunded)), right: true);
                    TotalCell(table.Cell(), ReportPdfTheme.FormatMoney(rows.Sum(r => r.NetRevenue)), right: true);
                });
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

        private static void TotalCell(IContainer cell, string text, bool right = false)
        {
            var container = cell.Background(ReportPdfTheme.Mint).PaddingVertical(6).PaddingHorizontal(6);
            if (right)
            {
                container = container.AlignRight();
            }
            container.Text(text).Bold().FontColor(ReportPdfTheme.ForestDark).FontSize(9);
        }

        public DocumentMetadata GetMetadata() => new() { Title = "Travle — Revenue by Category & Region" };
    }
}
