using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Travle.Services.Database
{
    public class RefreshToken
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(500)]
        public string Token { get; set; } = string.Empty;

        public DateTime ExpiresAt { get; set; }

        // Foreign key to User
        public int UserId { get; set; }

        [ForeignKey("UserId")]
        public User User { get; set; } = null!;
    }
}
