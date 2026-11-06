using System.Data.Entity;
using System.Data.Entity.ModelConfiguration.Conventions;
using SIGEA.Web.Models;

namespace SIGEA.Web.DAL
{
    /// <summary>
    /// EF6 context for the SIGEA academic schema. Maps the canonical schema
    /// created by db/schema/01_schema.sql; the database initializer is
    /// disabled (see Global.asax) so EF never creates or drops the database.
    /// </summary>
    public class SchoolContext : DbContext
    {
        public SchoolContext() : base("name=SchoolContext") { }

        public DbSet<Person> People { get; set; }
        public DbSet<Student> Students { get; set; }
        public DbSet<Instructor> Instructors { get; set; }
        public DbSet<Department> Departments { get; set; }
        public DbSet<Course> Courses { get; set; }
        public DbSet<Enrollment> Enrollments { get; set; }
        public DbSet<OfficeAssignment> OfficeAssignments { get; set; }

        protected override void OnModelCreating(DbModelBuilder modelBuilder)
        {
            modelBuilder.Conventions.Remove<PluralizingTableNameConvention>();

            // Person: Table-Per-Hierarchy on dbo.Person with a Discriminator.
            modelBuilder.Entity<Person>()
                .ToTable("Person")
                .Map<Student>(m => m.Requires("Discriminator").HasValue("Student"))
                .Map<Instructor>(m => m.Requires("Discriminator").HasValue("Instructor"));

            modelBuilder.Entity<Course>().ToTable("Course");
            modelBuilder.Entity<Department>().ToTable("Department");
            modelBuilder.Entity<Enrollment>().ToTable("Enrollment");
            modelBuilder.Entity<OfficeAssignment>().ToTable("OfficeAssignment");

            // Department administrator (optional instructor).
            modelBuilder.Entity<Department>()
                .HasOptional(d => d.Administrator)
                .WithMany()
                .HasForeignKey(d => d.InstructorID);

            // Course <-> Instructor many-to-many via dbo.CourseAssignment.
            modelBuilder.Entity<Course>()
                .HasMany(c => c.Instructors)
                .WithMany(i => i.Courses)
                .Map(t => t.MapLeftKey("CourseID")
                           .MapRightKey("InstructorID")
                           .ToTable("CourseAssignment"));

            // Instructor 1:0..1 OfficeAssignment (shared PK).
            modelBuilder.Entity<Instructor>()
                .HasOptional(i => i.OfficeAssignment)
                .WithRequired(o => o.Instructor);

            base.OnModelCreating(modelBuilder);
        }
    }
}
