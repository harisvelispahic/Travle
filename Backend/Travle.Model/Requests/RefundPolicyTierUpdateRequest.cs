namespace Travle.Model.Requests
{
    public class RefundPolicyTierUpdateRequest
    {
        public int HoursBeforeMin { get; set; }
        public int? HoursBeforeMax { get; set; }
        public int Percentage { get; set; }
    }
}
