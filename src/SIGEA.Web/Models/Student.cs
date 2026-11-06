using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SIGEA.Web.Models
{
    /// <summary>A student (Discriminator = 'Student').</summary>
    public class Student : Person
    {
        [DataType(DataType.Date)]
        [DisplayFormat(DataFormatString = "{0:yyyy-MM-dd}", ApplyFormatInEditMode = true)]
        [Display(Name = "Fecha de matrícula")]
        public DateTime? EnrollmentDate { get; set; }

        public virtual ICollection<Enrollment> Enrollments { get; set; }
    }
}
