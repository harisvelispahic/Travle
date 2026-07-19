namespace Travle.Model.Responses
{
    public class RefundPolicyTierResponse
    {
        public int Id { get; set; }
        public int HoursBeforeMin { get; set; }
        public int? HoursBeforeMax { get; set; }
        public int Percentage { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
