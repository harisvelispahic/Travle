namespace Travle.Model.SearchObjects
{
    public class RefundPolicyTierSearch : BaseSearchObject
    {
        /// <summary>Filter tiers by exact refund percentage.</summary>
        public int? Percentage { get; set; }
    }
}
