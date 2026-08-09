# Reports & PDF generation

Authoritative reference for Phase 11 (Reports & dashboard), focused on the part that is the least
obvious and the most interesting to defend: **how the two PDF reports are generated**. The dashboard and
organizer-statistics screens are ordinary JSON-over-HTTP aggregates; the PDF pipeline is where the
design decisions live.

## 1. What the reporting module contains

| Piece | Audience | Endpoint(s) | Shape |
|---|---|---|---|
| Admin dashboard | Admin | `GET /Reports/dashboard` | JSON (tiles + chart series + activity) |
| Most popular destinations by period | Admin | `GET /Reports/popular-destinations` (+ `/pdf`) | JSON preview **and** PDF |
| Revenue by category / region | Admin | `GET /Reports/revenue` (+ `/pdf`) | JSON preview **and** PDF |
| Organizer statistics | Organizer | `GET /Reports/organizer-stats` | JSON |

The course requires (`01-course-constraints.md` §B) a reporting module on the desktop app with **at least
two PDF reports, downloadable and printable**. The two reports above satisfy that. Everything is
read-only; no reporting endpoint mutates data.

## 2. The one rule that shapes the whole design: the server owns the document

A report is aggregated data rendered for print. Two things must stay server-side:

1. **The aggregation** — totals, GroupBy, revenue attribution. The client must never re-derive money
   (course §M, §H). All aggregates run at the database inside `ReportService`.
2. **The document composition** — so the on-screen preview table and the printed PDF can never drift
   apart, and so no report layout logic leaks into the Flutter client.

Both the JSON preview endpoint and the PDF endpoint call the **same** service method and are fed the
**same DTO**. The PDF endpoint just additionally renders that DTO into a document:

```
GET /Reports/revenue      → ReportService.GetRevenueReportAsync(search)          → RevenueReport (JSON)
GET /Reports/revenue/pdf  → GetRevenueReportAsync(search) → RevenueReportDocument → byte[] (application/pdf)
```

```csharp
public async Task<byte[]> GetRevenuePdfAsync(RevenueReportSearch search, CancellationToken ct)
{
    // Same admin-guarded aggregate the JSON endpoint returns…
    var report = await GetRevenueReportAsync(search, ct);
    // …then composed into a PDF. Rendering is pure: no DB access, no business logic.
    return new RevenueReportDocument(report).GeneratePdf();
}
```

That single-source-of-truth property is the reason the preview you see on screen and the PDF you download
always agree, even after a filter change.

## 3. End-to-end flow

```
Desktop (ReportsScreen)
  │  user picks a period, clicks "Download PDF"
  ▼
ReportProvider.revenuePdf(filter)               UI/travle_core/.../report_provider.dart
  │  GET /Reports/revenue/pdf?FromDate=…&ToDate=…   (Bearer JWT, 401→refresh retry)
  ▼
ReportsController.RevenuePdf  [Authorize(AdminOnly)]   Backend/.../ReportsController.cs
  │  returns File(bytes, "application/pdf", "travle-revenue.pdf")
  ▼
ReportService.GetRevenuePdfAsync                 Backend/.../Reports/ReportService.cs
  │  aggregate → RevenueReport DTO
  ▼
RevenueReportDocument(report).GeneratePdf()      Backend/.../Reports/Documents/*.cs
  │  QuestPDF composes + SkiaSharp renders → byte[]
  ▼
Desktop: saveReportPdf(bytes, name)              UI/travle_desktop/lib/util/report_download.dart
     FilePicker.saveFile → write bytes → snackbar with "Open" (OS default viewer → print)
```

Files:
- Backend service + PDF: `Backend/Travle.Services/Reports/` (`ReportService.cs`, `Documents/`).
- Controller: `Backend/Travle.WebAPI/Controllers/ReportsController.cs`.
- Desktop: `UI/travle_desktop/lib/screens/reports_screen.dart`, `lib/util/report_download.dart`,
  and `UI/travle_core/lib/src/providers/report_provider.dart`.

## 4. How QuestPDF actually works

QuestPDF is a **code-first, declarative** PDF library. You do not draw at pixel coordinates and you do
not write HTML; you describe a layout tree with a fluent C# API, and QuestPDF's **retained-mode layout
engine** measures it, breaks it across pages, and renders it. Rendering is done by **SkiaSharp** (the
.NET binding to Google's Skia graphics engine — the same engine Flutter and Chrome use), which emits real
vector PDF content (selectable text, crisp at any zoom), not a rasterized image.

### 4.1 A document is an `IDocument`

Each report is a class implementing `QuestPDF.Infrastructure.IDocument` with a single `Compose` method:

```csharp
internal sealed class RevenueReportDocument : IDocument
{
    private readonly RevenueReport _report;
    public RevenueReportDocument(RevenueReport report) => _report = report;

    public void Compose(IDocumentContainer container)
    {
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(28);
            page.DefaultTextStyle(s => s.FontSize(10).FontColor(ReportPdfTheme.ForestDark));

            page.Header().Element(c => ReportPdfTheme.ComposeHeader(c, "Revenue by Category & Region", subtitle));
            page.Content().PaddingTop(14).Column(col =>
            {
                col.Item().Element(ComposeTotals);                       // the grand-totals strip
                col.Item().Element(c => ComposeSection(c, "By Category", _report.ByCategory));
                col.Item().Element(c => ComposeSection(c, "By Region",   _report.ByRegion));
            });
            page.Footer().Element(ReportPdfTheme.ComposeFooter);         // "Page x of y"
        });
    }
}
```

Key ideas visible here:

- **Composition, not coordinates.** `Row`, `Column`, `Table`, `Padding`, `Background`, `AlignRight`
  compose like Flutter widgets. QuestPDF resolves sizes itself.
- **Automatic pagination.** `page.Header()`/`page.Footer()` repeat on every page; a `Table` that
  overflows A4 continues on the next page with its header row repeated. We never compute page breaks — a
  20-row report and a 500-row report both "just work".
- **Tables** are declared with `ColumnsDefinition` (relative vs constant widths), a `Header`, and body
  cells; numeric columns are right-aligned and each revenue section ends with a bold **Total** row that
  reconciles to the totals strip.

### 4.2 Shared theme (`ReportPdfTheme`)

`Reports/Documents/ReportPdfTheme.cs` centralises everything both documents share so they read as one
family and never diverge:

- The **brand palette** (`Forest #235347`, `Mint`, …) mirroring the desktop `TravleTokens`.
- **Formatters**: `FormatMoney` (`"1,234.50 KM"`, invariant culture), `FormatDate`, `FormatPeriod`.
- The **branded header band** (Travle wordmark + title + period + "Generated …" date) and the **footer**
  (page x of y).
- Cell helpers (`HeaderCell`, `BodyCell` with zebra striping).

### 4.3 Fonts, and why the Docker image needed one line

SkiaSharp does text shaping through the native `libSkiaSharp` library, which on Linux depends on
**fontconfig**. The base `mcr.microsoft.com/dotnet/aspnet:10.0` (Debian) image does not ship it, so the
first PDF request in a container would throw. QuestPDF itself **bundles the Lato font family** (and Lato
covers the Bosnian diacritics č/ć/š/ž/đ we render), so we do **not** need to install any font files — we
only need the native dependency. Hence one line in `Travle.WebAPI/Dockerfile`:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*
```

Locally on Windows this problem doesn't exist (fontconfig/system fonts are present), which is why it
rendered in dev before the Docker fix.

### 4.4 Licensing

QuestPDF is dual-licensed. The **Community licence is free** for companies/individuals under a revenue
threshold (well within a student seminar project) and unlocks the full API. It must be set once before
any document is generated; we do it at startup in `Program.cs`:

```csharp
QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;
```

Omitting this throws at first render, so it lives next to the other one-time startup configuration.

### 4.5 "Downloadable and printable"

A generated PDF is inherently printable — any PDF viewer prints it. So we do **not** ship an in-app print
dialog or the `printing` package. The desktop `saveReportPdf` helper (a) opens the native **Save**
dialog via `FilePicker.saveFile`, (b) writes the bytes, and (c) shows a snackbar with an **Open** action
that launches the file in the OS default viewer (`cmd /c start` on Windows), one Ctrl+P from a printout.
Downloadable **and** printable, no extra dependency.

## 5. Why QuestPDF (and not the alternatives)

| Option | Why not |
|---|---|
| **iText 7** | AGPL or paid commercial licence. AGPL is viral (would force the whole app open under AGPL); the commercial licence is expensive. Rejected on licensing alone. |
| **PdfSharp / MigraDoc** | Lower-level and older API. PdfSharp is essentially a drawing surface (manual coordinates/pagination); MigraDoc adds a document model but with a dated, verbose API and weaker table ergonomics for a financial report. |
| **DinkToPdf / wkhtmltopdf** | Renders HTML→PDF via a bundled **native `wkhtmltopdf` binary**. That means shipping/maintaining a platform-specific binary in the image, a heavier and more fragile Docker build, and wkhtmltopdf is effectively unmaintained/archived. |
| **Flutter `pdf` package (client-side)** | Would move report layout into the Flutter client and duplicate the data-shaping there, so the preview and the PDF could drift, and the client would own document logic that belongs on the server. Contradicts §2. |
| **QuestPDF** ✅ | Modern **fluent, code-first** C# API; **automatic layout + pagination**; **SkiaSharp** vector output (selectable text, sharp print); **free Community licence**; no HTML engine or native binary to manage (only `libfontconfig1`); document classes are plain C# that are easy to unit-test and to keep DRY via a shared theme; excellent fit for tabular/financial reports. |

In short: QuestPDF let us keep composition on the server, next to the data, with the least operational
baggage and no licensing risk — while producing clean, branded, paginated, print-quality tables.

## 6. Course-constraint checklist (PDF-relevant)

- [x] **≥ 2 PDF reports, downloadable and printable** (popular destinations, revenue) — §B.
- [x] Reports are part of the **desktop administrative** module; PDF endpoints are `AdminOnly` — §B/§J.
- [x] **Server owns the data and the document**; the client never computes money — §M/§H.
- [x] Aggregations are DB-level; list/preview endpoints stay light (the PDF blob is on its own dedicated
      endpoint, never in a list payload) — §P.
- [x] Runs unattended in Docker (`libfontconfig1` added; Community licence set at startup) — §F/§Q.
