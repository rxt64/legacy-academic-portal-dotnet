using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SIGEA.Web.Models
{
    /// <summary>An academic department with a budget and optional administrator.</summary>
    public class Department
    {
        public int DepartmentID { get; set; }

        [Required, StringLength(50)]
        [Display(Name = "Departamento")]
        public string Name { get; set; }

        [DataType(DataType.Currency)]
        [Column(TypeName = "money")]
        [Display(Name = "Presupuesto")]
        public decimal Budget { get; set; }

        [DataType(DataType.Date)]
        [DisplayFormat(DataFormatString = "{0:yyyy-MM-dd}", ApplyFormatInEditMode = true)]
        [Display(Name = "Inicio")]
        public DateTime StartDate { get; set; }

        [Display(Name = "Administrador")]
        public int? InstructorID { get; set; }

        public virtual Instructor Administrator { get; set; }
        public virtual ICollection<Course> Courses { get; set; }
    }
}
