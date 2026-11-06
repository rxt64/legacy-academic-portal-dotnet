using System.Web.Mvc;
using SIGEA.Web.DAL;
using SIGEA.Web.Infrastructure;

namespace SIGEA.Web.Controllers
{
    /// <summary>
    /// Normal student transcript access. Requires an authenticated session AND
    /// enforces OWNERSHIP: a signed-in student may only view their own record.
    /// The lab endpoint (DOTNET-IDOR-01) omits the ownership check on purpose.
    /// </summary>
    public class TranscriptController : Controller
    {
        private readonly SchoolContext db = new SchoolContext();

        /// <summary>The signed-in student's own transcript.</summary>
        public ActionResult Mine()
        {
            var sid = SessionUser.GetStudentId(HttpContext);
            if (sid == null) return RedirectToAction("Login", "Account");
            var vm = new TranscriptService(db).Build(sid.Value);
            if (vm == null) return HttpNotFound();
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
                return new HttpStatusCodeResult(403, "No autorizado para ver este expediente.");

            var vm = new TranscriptService(db).Build(id);
            if (vm == null) return HttpNotFound();
            return View(vm);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) db.Dispose();
            base.Dispose(disposing);
        }
    }
}
