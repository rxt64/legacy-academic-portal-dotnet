using System.ComponentModel.DataAnnotations;

namespace SIGEA.Web.Models
{
    /// <summary>A student's enrollment in a course, with an optional grade (0.00-4.00 GPA points).</summary>
    public class Enrollment
    {
        public int EnrollmentID { get; set; }
        public int CourseID { get; set; }
        public int StudentID { get; set; }

        [Range(0, 4)]
        [Display(Name = "Calificación")]
        public decimal? Grade { get; set; }

        public virtual Course Course { get; set; }
        public virtual Student Student { get; set; }
    }
}
