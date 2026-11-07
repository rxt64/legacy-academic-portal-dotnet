using System.Linq;
using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SIGEA.Web.DAL;
using SIGEA.Web.Models;

namespace SIGEA.Web.Controllers
{
    public class InstructorsController : Controller
    {
        private readonly SchoolContext db;

        public InstructorsController(SchoolContext db)
        {
            this.db = db;
        }

        public ActionResult Index()
        {
            var instructors = db.People.OfType<Instructor>()
                .Include(i => i.OfficeAssignment)
                .Include(i => i.Courses)
                .OrderBy(i => i.LastName).ToList();
            return View(instructors);
        }

        public ActionResult Details(int? id)
        {
            if (id == null) return new StatusCodeResult((int)HttpStatusCode.BadRequest);
            var instructor = db.People.OfType<Instructor>()
                .Include(i => i.OfficeAssignment).Include(i => i.Courses)
                .FirstOrDefault(i => i.ID == id);
            if (instructor == null) return NotFound();
            return View(instructor);
        }

        public ActionResult Create()
        {
            return View(new Instructor());
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Create([Bind("LastName,FirstName,Email,HireDate")] Instructor instructor)
        {
            if (ModelState.IsValid)
            {
                db.Instructors.Add(instructor);
                db.SaveChanges();
                return RedirectToAction("Details", new { id = instructor.ID });
            }
            return View(instructor);
        }

        public ActionResult Edit(int? id)
        {
            if (id == null) return new StatusCodeResult((int)HttpStatusCode.BadRequest);
            var instructor = db.Instructors.Find(id);
            if (instructor == null) return NotFound();
            return View(instructor);
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Edit([Bind("ID,LastName,FirstName,Email,HireDate")] Instructor instructor)
        {
            if (ModelState.IsValid)
            {
                db.Entry(instructor).State = EntityState.Modified;
                db.SaveChanges();
                return RedirectToAction("Details", new { id = instructor.ID });
            }
            return View(instructor);
        }

        public ActionResult Delete(int? id)
        {
            if (id == null) return new StatusCodeResult((int)HttpStatusCode.BadRequest);
            var instructor = db.Instructors.Find(id);
            if (instructor == null) return NotFound();
            return View(instructor);
        }

        [HttpPost, ActionName("Delete"), ValidateAntiForgeryToken]
        public ActionResult DeleteConfirmed(int id)
        {
            var instructor = db.Instructors.Find(id);
            if (instructor != null)
            {
                db.Instructors.Remove(instructor);
                db.SaveChanges();
            }
            return RedirectToAction("Index");
        }
    }
}
