using System.Web.Mvc;
using SIGEA.Web.DAL;
using SIGEA.Web.Infrastructure;

namespace SIGEA.Web.Controllers
{
    /// <summary>
    /// Vulnerability-lab routes. Every action carries [LabOnly], so when the
    /// labs are disabled (default) or the caller is not on loopback, the
    /// actions return 404. Contains SECURITY-LAB DOTNET-SQLI-01 and
    /// SECURITY-LAB DOTNET-IDOR-01.
    /// </summary>
    [LabOnly]
    public class LabController : Controller
    {
        private readonly SchoolContext db = new SchoolContext();

        public ActionResult Index()
        {
            return View();
        }

        // ---------------------------------------------------------------
        // SECURITY-LAB DOTNET-SQLI-01 — SQL injection via string concatenation
        // ---------------------------------------------------------------
        public ActionResult Sqli(string term)
        {
            ViewBag.Term = term;
            if (!string.IsNullOrEmpty(term))
            {
                ViewBag.Sql = LabQueries.BuildSql(term);
                ViewBag.Rows = LabQueries.VulnerableSearch(term);
            }
            return View();
        }

        // ---------------------------------------------------------------
        // SECURITY-LAB DOTNET-IDOR-01 — missing per-object authorization
        //
        // Requires an authenticated student session (identity from session,
        // not a parameter), but DOES NOT verify that the requested transcript
        // belongs to the signed-in student. Changing the id reveals another
        // student's synthetic record. The normal TranscriptController.Details
        // enforces ownership.
        // ---------------------------------------------------------------
        public ActionResult Transcript(int? id)
        {
            var sid = SessionUser.GetStudentId(HttpContext);
            if (sid == null) return RedirectToAction("Login", "Account");

            // Authenticated, yes. Authorized for THIS id? Not checked (the bug).
            int target = id ?? sid.Value;
            var vm = new TranscriptService(db).Build(target);
            if (vm == null) return HttpNotFound();

            ViewBag.SessionStudentId = sid.Value;
            return View(vm);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) db.Dispose();
            base.Dispose(disposing);
        }
    }
}
