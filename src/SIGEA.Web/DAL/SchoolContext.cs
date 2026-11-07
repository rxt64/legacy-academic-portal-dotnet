using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using SIGEA.Web.Models;

namespace SIGEA.Web.DAL
{
    /// <summary>
    /// EF Core context for the SIGEA academic schema. Maps the canonical schema
    /// created by db/schema/01_schema.sql; the database is never created or
    /// migrated by EF Core (see Program.cs), matching the original EF6
    /// behavior where the initializer was disabled.
    /// </summary>
    public class SchoolContext : DbContext
    {
        /// <summary>Primary constructor used by ASP.NET Core dependency injection.</summary>
        public SchoolContext(DbContextOptions<SchoolContext> options) : base(options) { }

        /// <summary>
        /// Back-compat parameterless constructor for ad-hoc/test usage (mirrors the
        /// legacy EF6 "name=SchoolContext" behavior): resolves the connection string
        /// from configuration (appsettings.json + environment variables) rather than
        /// through DI.
        /// </summary>
        public SchoolContext() : base(BuildOptions()) { }

        private static DbContextOptions<SchoolContext> BuildOptions()
        {
            var env = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";
            var config = new ConfigurationBuilder()
                .SetBasePath(AppContext.BaseDirectory)
                .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
                .AddJsonFile($"appsettings.{env}.json", optional: true, reloadOnChange: false)
                .AddEnvironmentVariables()
                .Build();

            var cs = ResolveConnectionString(config, "SchoolContext");
            var builder = new DbContextOptionsBuilder<SchoolContext>();
            builder.UseSqlServer(cs);
            return builder.Options;
        }

        /// <summary>
        /// Resolves a named connection string from configuration, substituting any
        /// <c>${ENV_VAR}</c> placeholder (e.g. <c>${SIGEA_APP_PASSWORD}</c> for local
        /// SQL-auth development) with the corresponding environment variable. Azure SQL
        /// Managed Instance connection strings authenticate via Managed Identity and
        /// carry no password placeholder, so this is a no-op for them.
        /// </summary>
        public static string ResolveConnectionString(IConfiguration config, string name)
        {
            var cs = config.GetConnectionString(name);
            if (string.IsNullOrWhiteSpace(cs))
            {
                return "Server=localhost;Database=SIGEA;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True";
            }

            var envPw = Environment.GetEnvironmentVariable("SIGEA_APP_PASSWORD");
            if (!string.IsNullOrEmpty(envPw) && cs.Contains("${SIGEA_APP_PASSWORD}"))
            {
                cs = cs.Replace("${SIGEA_APP_PASSWORD}", envPw);
            }
            return cs;
        }

        public DbSet<Person> People { get; set; }
        public DbSet<Student> Students { get; set; }
        public DbSet<Instructor> Instructors { get; set; }
        public DbSet<Department> Departments { get; set; }
        public DbSet<Course> Courses { get; set; }
        public DbSet<Enrollment> Enrollments { get; set; }
        public DbSet<OfficeAssignment> OfficeAssignments { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Person: Table-Per-Hierarchy on dbo.Person with a Discriminator.
            modelBuilder.Entity<Person>(p =>
            {
                p.ToTable("Person");
                p.HasKey(x => x.ID);
                p.HasDiscriminator<string>("Discriminator")
                    .HasValue<Student>("Student")
                    .HasValue<Instructor>("Instructor");
            });

            modelBuilder.Entity<Course>().ToTable("Course");
            modelBuilder.Entity<Department>().ToTable("Department");
            modelBuilder.Entity<Enrollment>().ToTable("Enrollment");
            modelBuilder.Entity<OfficeAssignment>().ToTable("OfficeAssignment");

            modelBuilder.Entity<Department>().Property(d => d.Budget).HasColumnType("money");
            modelBuilder.Entity<Enrollment>().Property(e => e.Grade).HasColumnType("decimal(3,2)");

            // Course: CourseID is an assigned business key (not identity).
            modelBuilder.Entity<Course>().Property(c => c.CourseID).ValueGeneratedNever();

            // Department administrator (optional instructor).
            modelBuilder.Entity<Department>()
                .HasOne(d => d.Administrator)
                .WithMany()
                .HasForeignKey(d => d.InstructorID)
                .OnDelete(DeleteBehavior.Restrict);

            // Course <-> Instructor many-to-many via dbo.CourseAssignment.
            modelBuilder.Entity<Course>()
                .HasMany(c => c.Instructors)
                .WithMany(i => i.Courses)
                .UsingEntity<Dictionary<string, object>>(
                    "CourseAssignment",
                    j => j.HasOne<Instructor>().WithMany().HasForeignKey("InstructorID").HasConstraintName("FK_CA_Instructor"),
                    j => j.HasOne<Course>().WithMany().HasForeignKey("CourseID").HasConstraintName("FK_CA_Course"),
                    j =>
                    {
                        j.ToTable("CourseAssignment");
                        j.HasKey("CourseID", "InstructorID");
                    });

            // Instructor 1:0..1 OfficeAssignment (shared PK).
            modelBuilder.Entity<OfficeAssignment>().HasKey(o => o.InstructorID);
            modelBuilder.Entity<Instructor>()
                .HasOne(i => i.OfficeAssignment)
                .WithOne(o => o.Instructor)
                .HasForeignKey<OfficeAssignment>(o => o.InstructorID);

            base.OnModelCreating(modelBuilder);
        }
    }
}
