using System.Linq.Expressions;
using System.Reflection;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    /// <summary>
    /// One place for the accent-aware "does any of these columns contain the search term" filter, so a
    /// service's search reduces to a single <c>query.WhereContains(term, x =&gt; x.Name)</c> call instead of
    /// repeating the <see cref="SearchCollation.HasDiacritics"/> branch and the two <c>COLLATE</c> variants
    /// (which was copy-pasted across a dozen services). The collation is chosen once from the term — a plain
    /// term is accent-insensitive ("Poc" matches "Počitelj"); an accented term stays accent-sensitive — and
    /// applied to every supplied column; a row matches when ANY column contains the term.
    /// <para>
    /// Built as an expression tree so the chosen collation is emitted as a <b>constant</b> (EF's
    /// <c>Collate</c> requires a literal collation, never a parameter — see <see cref="SearchCollation"/>),
    /// while the term itself stays a bound parameter (closed over a holder), exactly as the hand-written
    /// per-service filters did.
    /// </para>
    /// </summary>
    public static class TextSearch
    {
        private static readonly MethodInfo CollateMethod = typeof(RelationalDbFunctionsExtensions)
            .GetMethod(nameof(RelationalDbFunctionsExtensions.Collate))!
            .MakeGenericMethod(typeof(string));

        private static readonly MethodInfo StringContains =
            typeof(string).GetMethod(nameof(string.Contains), new[] { typeof(string) })!;

        private static readonly MemberExpression EfFunctions =
            Expression.Property(null, typeof(EF).GetProperty(nameof(EF.Functions))!);

        /// <summary>
        /// Filters <paramref name="query"/> to rows where any of <paramref name="columns"/> contains
        /// <paramref name="term"/>, accent-awareness picked from the term. A null/blank term (or no columns)
        /// leaves the query unchanged, so callers can pass an optional search field straight through.
        /// </summary>
        public static IQueryable<T> WhereContains<T>(
            this IQueryable<T> query,
            string? term,
            params Expression<Func<T, string?>>[] columns)
        {
            if (string.IsNullOrWhiteSpace(term) || columns.Length == 0)
            {
                return query;
            }

            // Compile-time literal per branch — the collation must reach EF as a constant, not a variable.
            var collation = SearchCollation.HasDiacritics(term)
                ? SearchCollation.CaseInsensitiveAccentSensitive
                : SearchCollation.CaseInsensitiveAccentInsensitive;
            var collationConst = Expression.Constant(collation);

            // Close over the term through a holder so EF binds it as a parameter (not inlined as a literal).
            var termExpr = Expression.Property(
                Expression.Constant(new TermHolder(term)), nameof(TermHolder.Value));

            var parameter = Expression.Parameter(typeof(T), "e");
            Expression? predicate = null;

            foreach (var column in columns)
            {
                var member = new ParameterRebinder(column.Parameters[0], parameter).Visit(column.Body)!;
                // EF.Functions.Collate(member, collation).Contains(term)
                var collated = Expression.Call(CollateMethod, EfFunctions, member, collationConst);
                var contains = Expression.Call(collated, StringContains, termExpr);
                predicate = predicate is null ? contains : Expression.OrElse(predicate, contains);
            }

            var lambda = Expression.Lambda<Func<T, bool>>(predicate!, parameter);
            return query.Where(lambda);
        }

        private sealed class TermHolder
        {
            public TermHolder(string value) => Value = value;
            public string Value { get; }
        }

        // Rebinds a caller's single-parameter selector onto the shared lambda parameter, so several column
        // selectors can be OR-ed under one predicate.
        private sealed class ParameterRebinder : ExpressionVisitor
        {
            private readonly ParameterExpression _from;
            private readonly ParameterExpression _to;

            public ParameterRebinder(ParameterExpression from, ParameterExpression to)
            {
                _from = from;
                _to = to;
            }

            protected override Expression VisitParameter(ParameterExpression node)
                => node == _from ? _to : base.VisitParameter(node);
        }
    }
}
