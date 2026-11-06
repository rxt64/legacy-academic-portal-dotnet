using System.Linq;
using System.Web.Mvc;
using SIGEA.Web.DAL;
using SIGEA.Web.Infrastructure;
using SIGEA.Web.Models;

namespace SIGEA.Web.Controllers
{
    /// <summary>
    /// Minimal session login for the student self-service area. A learner
    /// "signs in" with a student email; the authenticated student's ID is held
    /// in the session (never in a request parameter). This is intentionally
    /// simple — it exists so the IDOR lab can contrast an AUTHENTICATED session
    /// with an AUTHORIZED record access. It is not a production auth system.
    /// </summary>
    public class AccountController : Controller
    {
        private readonly SchoolContext db = new SchoolContext();

        [HttpGet]
        public ActionResult Login()
        {
            ViewBag.Current = SessionUser.GetStudentName(HttpContext);
            return View();
        }

        [HttpPost, ValidateAntiForgeryToken]
        public ActionResult Login(string email)
        {
            var student = db.People.OfType<Student>()
                .FirstOrDefault(s => s.Email == email);
            if (student == null)
            {
                ModelState.AddModelError("", "No hay un estudiante con ese correo (datos ficticios).");
                return View();
            }
            SessionUser.SignIn(HttpContext, student.ID, student.FullName);
            return RedirectToAction("Mine", "Transcript");
        }

        public ActionResult Logout()
        {
            SessionUser.SignOut(HttpContext);
            return RedirectToAction("Login");
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) db.Dispose();
            base.Dispose(disposing);
        }
    }
}
