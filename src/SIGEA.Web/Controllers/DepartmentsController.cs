using System.Data.Entity;
using System.Linq;
using System.Net;
using System.Web.Mvc;
using SIGEA.Web.DAL;
using SIGEA.Web.Models;

namespace SIGEA.Web.Controllers
{
    public class DepartmentsController : Controller
    {
        private readonly SchoolContext db = new SchoolContext();

        public ActionResult Index()
        {
            var departments = db.Departments.Include(d => d.Administrator)
                .OrderByDescending(d => d.Budget).ToList();
            return View(departments);
        }

        public ActionResult Details(int? id)
        {
            if (id == null) return new HttpStatusCodeResult(HttpStatusCode.BadRequest);
            var department = db.Departments.Include(d => d.Administrator).Include(d => d.Courses)
                .FirstOrDefault(d => d.DepartmentID == id);
            if (department == null) return HttpNotFound();
            return View(department);
        }

        public ActionResult Create()
        {
            PopulateAdministrators(null);
            return View(new Department { StartDate = System.DateTime.Today });
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Create([Bind(Include = "Name,Budget,StartDate,InstructorID")] Department department)
        {
            if (ModelState.IsValid)
            {
                db.Departments.Add(department);
                db.SaveChanges();
                return RedirectToAction("Details", new { id = department.DepartmentID });
            }
            PopulateAdministrators(department.InstructorID);
            return View(department);
        }

        public ActionResult Edit(int? id)
        {
            if (id == null) return new HttpStatusCodeResult(HttpStatusCode.BadRequest);
            var department = db.Departments.Find(id);
            if (department == null) return HttpNotFound();
            PopulateAdministrators(department.InstructorID);
            return View(department);
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Edit([Bind(Include = "DepartmentID,Name,Budget,StartDate,InstructorID")] Department department)
        {
            if (ModelState.IsValid)
            {
                db.Entry(department).State = EntityState.Modified;
                db.SaveChanges();
                return RedirectToAction("Details", new { id = department.DepartmentID });
            }
            PopulateAdministrators(department.InstructorID);
            return View(department);
        }

        public ActionResult Delete(int? id)
        {
            if (id == null) return new HttpStatusCodeResult(HttpStatusCode.BadRequest);
            var department = db.Departments.Include(d => d.Administrator).FirstOrDefault(d => d.DepartmentID == id);
            if (department == null) return HttpNotFound();
            return View(department);
        }

        [HttpPost, ActionName("Delete"), ValidateAntiForgeryToken]
        public ActionResult DeleteConfirmed(int id)
        {
            var department = db.Departments.Find(id);
            if (department != null && !db.Courses.Any(c => c.DepartmentID == id))
            {
                db.Departments.Remove(department);
                db.SaveChanges();
                return RedirectToAction("Index");
            }
            // Keep referential integrity: refuse delete when courses remain.
            TempData["Flash"] = "No se puede eliminar un departamento con cursos asociados.";
            return RedirectToAction("Details", new { id });
        }

        private void PopulateAdministrators(int? selected)
        {
            ViewBag.InstructorID = new SelectList(
                db.People.OfType<Instructor>().OrderBy(i => i.LastName),
                "ID", "FullName", selected);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) db.Dispose();
            base.Dispose(disposing);
        }
    }
}
