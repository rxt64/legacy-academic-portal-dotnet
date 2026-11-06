using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SIGEA.Web.Models
{
    /// <summary>An instructor (Discriminator = 'Instructor').</summary>
    public class Instructor : Person
    {
        [DataType(DataType.Date)]
        [DisplayFormat(DataFormatString = "{0:yyyy-MM-dd}", ApplyFormatInEditMode = true)]
        [Display(Name = "Fecha de contratación")]
        public DateTime? HireDate { get; set; }

        public virtual ICollection<Course> Courses { get; set; }
        public virtual OfficeAssignment OfficeAssignment { get; set; }
    }
}
