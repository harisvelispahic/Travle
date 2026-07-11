using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Travle.Services.Database
{
    public class ProductReview
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        [Range(1, 5)]
        public int Rating { get; set; }
        
        [MaxLength(1000)]
        public string Comment { get; set; } = string.Empty;
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        // User who wrote the review
        public int UserId { get; set; }
        
        [ForeignKey("UserId")]
        public User User { get; set; } = null!;
        
        // Product that was reviewed
        public int ProductId { get; set; }
        
        [ForeignKey("ProductId")]
        public Product Product { get; set; } = null!;

        /// <summary>Optional link to the order that contained this product (used to verify purchase).</summary>
        public int? OrderId { get; set; }

        [ForeignKey("OrderId")]
        public Order? Order { get; set; }
        
        // Whether the review is approved/visible
        public bool IsApproved { get; set; } = false;
    }
} 