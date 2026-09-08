namespace Travle.Model.Requests
{
    /// <summary>
    /// The whole refund ladder in one request. The tiers only mean something together — they have to tile
    /// every hour before departure exactly once, with refunds rising as notice grows — so a single row is
    /// not an editable unit: inserting one necessarily overlaps a neighbour, and deleting one necessarily
    /// leaves a gap. The ladder is therefore replaced as a set, validated as a set, and committed in one
    /// transaction.
    /// </summary>
    public class RefundPolicyLadderRequest
    {
        public List<RefundPolicyLadderTier> Tiers { get; set; } = new List<RefundPolicyLadderTier>();
    }

    /// <summary>One rung: the window it covers and what it refunds. <c>HoursBeforeMax</c> null = open-ended.</summary>
    public class RefundPolicyLadderTier
    {
        public int HoursBeforeMin { get; set; }
        public int? HoursBeforeMax { get; set; }
        public int Percentage { get; set; }
    }
}
