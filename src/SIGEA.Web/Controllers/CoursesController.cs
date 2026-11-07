using System.Linq;
using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using SIGEA.Web.DAL;
using SIGEA.Web.Models;

namespace SIGEA.Web.Controllers
{
    public class CoursesController : Controller
    {
        private readonly SchoolContext db;

        public CoursesController(SchoolContext db)
        {
            this.db = db;
        }

        public ActionResult Index()
        {
            var courses = db.Courses.Include(c => c.Department)
                .OrderBy(c => c.CourseID).ToList();
            return View(courses);
        }

        public ActionResult Details(int? id)
        {
            if (id == null) return new StatusCodeResult((int)HttpStatusCode.BadRequest);
            var course = db.Courses.Include(c => c.Department).Include(c => c.Instructors)
                .FirstOrDefault(c => c.CourseID == id);
            if (course == null) return NotFound();
            return View(course);
        }

        public ActionResult Create()
        {
            PopulateDepartments(null);
            return View(new Course());
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Create([Bind("CourseID,Title,Credits,DepartmentID")] Course course)
        {
            if (ModelState.IsValid)
            {
                db.Courses.Add(course);
                db.SaveChanges();
                return RedirectToAction("Details", new { id = course.CourseID });
            }
            PopulateDepartments(course.DepartmentID);
            return View(course);
        }

        public ActionResult Edit(int? id)
        {
            if (id == null) return new StatusCodeResult((int)HttpStatusCode.BadRequest);
            var course = db.Courses.Find(id);
            if (course == null) return NotFound();
            PopulateDepartments(course.DepartmentID);
            return View(course);
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Edit([Bind("CourseID,Title,Credits,DepartmentID")] Course course)
        {
            if (ModelState.IsValid)
            {
                db.Entry(course).State = EntityState.Modified;
                db.SaveChanges();
                return RedirectToAction("Details", new { id = course.CourseID });
            }
            PopulateDepartments(course.DepartmentID);
            return View(course);
        }

        public ActionResult Delete(int? id)
        {
            if (id == null) return new StatusCodeResult((int)HttpStatusCode.BadRequest);
            var course = db.Courses.Include(c => c.Department).FirstOrDefault(c => c.CourseID == id);
            if (course == null) return NotFound();
            return View(course);
        }

        [HttpPost, ActionName("Delete"), ValidateAntiForgeryToken]
        public ActionResult DeleteConfirmed(int id)
        {
            var course = db.Courses.Find(id);
            if (course != null)
            {
                var enrollments = db.Enrollments.Where(e => e.CourseID == id);
                db.Enrollments.RemoveRange(enrollments);
                db.Courses.Remove(course);
                db.SaveChanges();
            }
            return RedirectToAction("Index");
        }

        private void PopulateDepartments(int? selected)
        {
            ViewBag.DepartmentID = new SelectList(
                db.Departments.OrderBy(d => d.Name), "DepartmentID", "Name", selected);
        }
    }
}
