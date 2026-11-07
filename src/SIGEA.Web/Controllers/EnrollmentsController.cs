using System.Linq;
using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using SIGEA.Web.DAL;
using SIGEA.Web.Models;

namespace SIGEA.Web.Controllers
{
    /// <summary>Enrollments and grades (matrículas y calificaciones).</summary>
    public class EnrollmentsController : Controller
    {
        private readonly SchoolContext db;

        public EnrollmentsController(SchoolContext db)
        {
            this.db = db;
        }

        public ActionResult Index(int? courseId)
        {
            var q = db.Enrollments.Include(e => e.Course).Include(e => e.Student).AsQueryable();
            if (courseId != null) q = q.Where(e => e.CourseID == courseId);
            ViewBag.Courses = new SelectList(db.Courses.OrderBy(c => c.Title), "CourseID", "Title", courseId);
            ViewBag.CourseId = courseId;
            return View(q.OrderBy(e => e.Course.Title).ToList());
        }

        public ActionResult Create()
        {
            PopulateLists(null, null);
            return View(new Enrollment());
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Create([Bind("CourseID,StudentID,Grade")] Enrollment enrollment)
        {
            if (ModelState.IsValid)
            {
                db.Enrollments.Add(enrollment);
                db.SaveChanges();
                return RedirectToAction("Index");
            }
            PopulateLists(enrollment.CourseID, enrollment.StudentID);
            return View(enrollment);
        }

        public ActionResult Edit(int? id)
        {
            if (id == null) return new StatusCodeResult((int)HttpStatusCode.BadRequest);
            var enrollment = db.Enrollments.Include(e => e.Course).Include(e => e.Student)
                .FirstOrDefault(e => e.EnrollmentID == id);
            if (enrollment == null) return NotFound();
            return View(enrollment);
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Edit([Bind("EnrollmentID,CourseID,StudentID,Grade")] Enrollment enrollment)
        {
            if (ModelState.IsValid)
            {
                db.Entry(enrollment).State = EntityState.Modified;
                db.SaveChanges();
                return RedirectToAction("Index");
            }
            return View(enrollment);
        }

        public ActionResult Delete(int? id)
        {
            if (id == null) return new StatusCodeResult((int)HttpStatusCode.BadRequest);
            var enrollment = db.Enrollments.Include(e => e.Course).Include(e => e.Student)
                .FirstOrDefault(e => e.EnrollmentID == id);
            if (enrollment == null) return NotFound();
            return View(enrollment);
        }

        [HttpPost, ActionName("Delete"), ValidateAntiForgeryToken]
        public ActionResult DeleteConfirmed(int id)
        {
            var enrollment = db.Enrollments.Find(id);
            if (enrollment != null)
            {
                db.Enrollments.Remove(enrollment);
                db.SaveChanges();
            }
            return RedirectToAction("Index");
        }

        private void PopulateLists(int? course, int? student)
        {
            ViewBag.CourseID = new SelectList(db.Courses.OrderBy(c => c.Title), "CourseID", "Title", course);
            ViewBag.StudentID = new SelectList(
                db.People.OfType<Student>().OrderBy(s => s.LastName), "ID", "FullName", student);
        }
    }
}
