using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using SIGEA.Web.DAL;
using SIGEA.Web.Infrastructure;

namespace SIGEA.Web.Controllers
{
    /// <summary>
    /// Normal student transcript access. Requires an authenticated session AND
    /// enforces OWNERSHIP: a signed-in student may only view their own record.
    /// </summary>
    public class TranscriptController : Controller
    {
        private readonly SchoolContext db;

        public TranscriptController(SchoolContext db)
        {
            this.db = db;
        }

        /// <summary>The signed-in student's own transcript.</summary>
        public ActionResult Mine()
        {
            var sid = SessionUser.GetStudentId(HttpContext);
            if (sid == null) return RedirectToAction("Login", "Account");
            var vm = new TranscriptService(db).Build(sid.Value);
            if (vm == null) return NotFound();
            return View("Details", vm);
        }

        /// <summary>
        /// View a transcript by id. AUTHORIZED path: the requested id must match
        /// the authenticated student. A different id is forbidden (403).
        /// </summary>
        public ActionResult Details(int id)
        {
            var sid = SessionUser.GetStudentId(HttpContext);
            if (sid == null) return RedirectToAction("Login", "Account");

            // Authentication is not authorization: verify object ownership.
            if (sid.Value != id)
                return StatusCode(StatusCodes.Status403Forbidden, "No autorizado para ver este expediente.");

            var vm = new TranscriptService(db).Build(id);
            if (vm == null) return NotFound();
            return View(vm);
        }
    }
}
