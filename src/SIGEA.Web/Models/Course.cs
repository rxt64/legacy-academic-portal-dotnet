using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SIGEA.Web.Models
{
    /// <summary>A course. CourseID is an assigned business key (not identity).</summary>
    public class Course
    {
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        [Display(Name = "Número")]
        public int CourseID { get; set; }

        [Required, StringLength(100)]
        [Display(Name = "Título")]
        public string Title { get; set; }

        [Range(1, 6)]
        [Display(Name = "Créditos")]
        public int Credits { get; set; }

        [Display(Name = "Departamento")]
        public int DepartmentID { get; set; }

        public virtual Department Department { get; set; }
        public virtual ICollection<Enrollment> Enrollments { get; set; }
        public virtual ICollection<Instructor> Instructors { get; set; }
    }
}
