namespace Travle.Model.SearchObjects;

public class OrderSearchObject : BaseSearchObject
{
    /// <summary>When set, filters orders by status enum underlying value.</summary>
    public int? Status { get; set; }
}
