using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Travle.Model.Requests
{
    public class AssetUpdateRequest
    {
        public int Id { get; set; }
        public string FileName { get; set; } = string.Empty;
        public string ContentType { get; set; } = string.Empty;
        public string Base64Content { get; set; } = string.Empty;
        public int ProductId { get; set; }
    }
}
