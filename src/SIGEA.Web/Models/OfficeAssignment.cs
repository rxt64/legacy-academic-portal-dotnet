using System.ComponentModel.DataAnnotations;

namespace SIGEA.Web.Models
{
    /// <summary>Office location for an instructor (1:0..1).</summary>
    public class OfficeAssignment
    {
        [Key]
        public int InstructorID { get; set; }

        [StringLength(50)]
        [Display(Name = "Oficina")]
        public string Location { get; set; }

        public virtual Instructor Instructor { get; set; }
    }
}
