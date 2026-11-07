using System.Linq;
using Microsoft.AspNetCore.Mvc;
using SIGEA.Web.DAL;
using SIGEA.Web.Models;

namespace SIGEA.Web.Controllers
{
    public class HomeController : Controller
    {
        private readonly SchoolContext db;

        public HomeController(SchoolContext db)
        {
            this.db = db;
        }

        /// <summary>Dashboard. Every indicator is computed in SQL Server (LINQ-to-Entities aggregates).</summary>
        public ActionResult Index()
        {
            var vm = new DashboardViewModel
            {
                StudentCount = db.People.OfType<Student>().Count(),
                InstructorCount = db.People.OfType<Instructor>().Count(),
                CourseCount = db.Courses.Count(),
                DepartmentCount = db.Departments.Count(),
                EnrollmentCount = db.Enrollments.Count(),
                GradedCount = db.Enrollments.Count(e => e.Grade != null),
                AverageGrade = db.Enrollments.Where(e => e.Grade != null).Average(e => (decimal?)e.Grade),
                TotalBudget = db.Departments.Sum(d => (decimal?)d.Budget) ?? 0m,
                Departments = db.Departments
                    .Select(d => new DepartmentSummary
                    {
                        DepartmentID = d.DepartmentID,
                        Name = d.Name,
                        Budget = d.Budget,
                        CourseCount = d.Courses.Count(),
                        EnrollmentCount = d.Courses.SelectMany(c => c.Enrollments).Count()
                    })
                    .OrderByDescending(x => x.Budget)
                    .ToList()
            };
            return View(vm);
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public ActionResult Error()
        {
            return View();
        }
    }
}
