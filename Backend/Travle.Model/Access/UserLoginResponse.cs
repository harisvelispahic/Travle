using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Travle.Model.Access
{
    public class UserLoginResponse
    {
        public string Accesstoken { get; set; } = string.Empty;
        public string Refreshtoken { get; set; } = string.Empty;

    }
}
