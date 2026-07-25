using System.Globalization;
using System.Text;

namespace Travle.Services
{
    /// <summary>
    /// Collations + a helper for <b>asymmetric</b> accent handling in text search, applied per query
    /// via <c>EF.Functions.Collate(column, collation).Contains(term)</c> — only the search <c>WHERE</c>
    /// is affected, so the columns' own collation, their unique indexes, and ordering keep the database
    /// default (no schema change / migration required).
    /// <para>
    /// The rule (driven by <see cref="HasDiacritics"/> on the <em>search term</em>):
    /// a plain-letter query is <b>accent-insensitive</b> so "Poc" still matches "Počitelj"; a query that
    /// itself carries a diacritic is <b>accent-sensitive</b> so "Šarajevo" does <i>not</i> match
    /// "Sarajevo". Both collations stay case-insensitive. Pick with:
    /// <code>collation = HasDiacritics(term) ? CaseInsensitiveAccentSensitive : CaseInsensitiveAccentInsensitive;</code>
    /// The chosen constant must be passed as a compile-time literal (a <c>const</c>) so EF emits it as a
    /// COLLATE literal — branch on <see cref="HasDiacritics"/> at the call site rather than passing a
    /// variable. The <c>_100_</c> collation version has the strongest Unicode weighting, folding the
    /// Bosnian diacritics (č, ć, š, ž) onto their base letters.
    /// </para>
    /// </summary>
    public static class SearchCollation
    {
        /// <summary>Case- and accent-insensitive: "poc" matches "Počitelj". Use for plain-letter terms.</summary>
        public const string CaseInsensitiveAccentInsensitive = "Latin1_General_100_CI_AI";

        /// <summary>Case-insensitive but accent-sensitive: "Šarajevo" won't match "Sarajevo". Use for accented terms.</summary>
        public const string CaseInsensitiveAccentSensitive = "Latin1_General_100_CI_AS";

        /// <summary>
        /// True if <paramref name="term"/> carries a diacritic — decomposing it (Unicode FormD) yields a
        /// combining mark, e.g. č → c + ̌ . Such terms are searched accent-sensitively; plain terms stay
        /// accent-insensitive. (Letters that don't decompose, e.g. đ, are treated as plain — acceptable,
        /// since the chosen collation still keeps đ distinct from d either way.)
        /// </summary>
        public static bool HasDiacritics(string term)
        {
            foreach (var ch in term.Normalize(NormalizationForm.FormD))
            {
                if (CharUnicodeInfo.GetUnicodeCategory(ch) == UnicodeCategory.NonSpacingMark)
                {
                    return true;
                }
            }
            return false;
        }
    }
}
