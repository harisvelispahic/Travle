
namespace Travle.Model.Responses
{
    public class PageResult<T>
    {
        public List<T> Items { get; set; } = new List<T>();
        public int? TotalCount { get; set; }
    }
}
