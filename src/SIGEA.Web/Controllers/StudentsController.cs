using System.Linq;
using System.Net;
using System.Web.Mvc;
using SIGEA.Web.DAL;
using SIGEA.Web.Models;

namespace SIGEA.Web.Controllers
{
    /// <summary>
    /// Student management. The academic search here is PARAMETERIZED via
    /// LINQ-to-Entities (the user term becomes a bound SQL parameter). The
    /// deliberately unsafe search lives only in LabController (DOTNET-SQLI-01).
    /// </summary>
    public class StudentsController : Controller
    {
        private readonly SchoolContext db = new SchoolContext();

        public ActionResult Index(string searchString)
        {
            var students = db.People.OfType<Student>().AsQueryable();
            if (!string.IsNullOrWhiteSpace(searchString))
            {
                // Safe: EF turns this into a parameterized LIKE.
                students = students.Where(s => s.LastName.Contains(searchString)
                                            || s.FirstName.Contains(searchString));
            }
            ViewBag.SearchString = searchString;
            return View(students.OrderBy(s => s.LastName).ThenBy(s => s.FirstName).ToList());
        }

        public ActionResult Details(int? id)
        {
            if (id == null) return new HttpStatusCodeResult(HttpStatusCode.BadRequest);
            var student = db.Students.Find(id);
            if (student == null) return HttpNotFound();
            return View(student);
        }

        public ActionResult Create()
        {
            return View(new Student());
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Create([Bind(Include = "LastName,FirstName,Email,EnrollmentDate")] Student student)
        {
            if (ModelState.IsValid)
            {
                db.Students.Add(student);
                db.SaveChanges();
                return RedirectToAction("Details", new { id = student.ID });
            }
            return View(student);
        }

        public ActionResult Edit(int? id)
        {
            if (id == null) return new HttpStatusCodeResult(HttpStatusCode.BadRequest);
            var student = db.Students.Find(id);
            if (student == null) return HttpNotFound();
            return View(student);
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Edit([Bind(Include = "ID,LastName,FirstName,Email,EnrollmentDate")] Student student)
        {
            if (ModelState.IsValid)
            {
                db.Entry(student).State = System.Data.Entity.EntityState.Modified;
                db.SaveChanges();
                return RedirectToAction("Details", new { id = student.ID });
            }
            return View(student);
        }

        public ActionResult Delete(int? id)
        {
            if (id == null) return new HttpStatusCodeResult(HttpStatusCode.BadRequest);
            var student = db.Students.Find(id);
            if (student == null) return HttpNotFound();
            return View(student);
        }

        [HttpPost, ActionName("Delete"), ValidateAntiForgeryToken]
        public ActionResult DeleteConfirmed(int id)
        {
            var student = db.Students.Find(id);
            if (student != null)
            {
                // Remove enrollments first to satisfy the FK.
                var enrollments = db.Enrollments.Where(e => e.StudentID == id);
                db.Enrollments.RemoveRange(enrollments);
                db.Students.Remove(student);
                db.SaveChanges();
            }
            return RedirectToAction("Index");
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) db.Dispose();
            base.Dispose(disposing);
        }
    }
}
