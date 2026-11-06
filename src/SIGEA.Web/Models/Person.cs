using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SIGEA.Web.Models
{
    /// <summary>
    /// Base person (Table-Per-Hierarchy). Concrete types Student and
    /// Instructor share the dbo.Person table, distinguished by a
    /// Discriminator column (configured in SchoolContext).
    /// </summary>
    public abstract class Person
    {
        public int ID { get; set; }

        [Required, StringLength(50)]
        [Display(Name = "Apellidos")]
        public string LastName { get; set; }

        [Required, StringLength(50)]
        [Display(Name = "Nombre")]
        public string FirstName { get; set; }

        [StringLength(100)]
        [Display(Name = "Correo")]
        public string Email { get; set; }

        [Display(Name = "Nombre completo")]
        public string FullName
        {
            get { return LastName + ", " + FirstName; }
        }
    }
}
