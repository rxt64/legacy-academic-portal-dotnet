using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using SIGEA.Web.DAL;
using SIGEA.Web.Infrastructure;

namespace SIGEA.Web.Controllers
{
    /// <summary>
    /// Vulnerability-lab routes. Every action carries [LabOnly], so when the
    /// labs are disabled (default) or the caller is not on loopback, the
    /// actions return 404. Contains the (remediated) SECURITY-LAB
    /// DOTNET-SQLI-01 and DOTNET-IDOR-01 exercises.
    /// </summary>
    [LabOnly]
    public class LabController : Controller
    {
        private readonly SchoolContext db;
        private readonly IConfiguration configuration;

        public LabController(SchoolContext db, IConfiguration configuration)
        {
            this.db = db;
            this.configuration = configuration;
        }

        public ActionResult Index()
        {
            return View();
        }

        // ---------------------------------------------------------------
        // SECURITY-LAB DOTNET-SQLI-01 — remediated: the search term is now
        // bound through a SqlParameter (@term) instead of being concatenated
        // into the SQL text. See DAL/LabQueries.cs.
        // ---------------------------------------------------------------
        public ActionResult Sqli(string term)
        {
            ViewBag.Term = term;
            if (!string.IsNullOrEmpty(term))
            {
                ViewBag.Sql = LabQueries.BuildSql();
                ViewBag.Rows = LabQueries.VulnerableSearch(term, configuration);
            }
            return View();
        }

        // ---------------------------------------------------------------
        // SECURITY-LAB DOTNET-IDOR-01 — remediated: this action now enforces
        // the same object-level ownership check as
        // TranscriptController.Details. Requires an authenticated student
        // session (identity from session, not a parameter) AND requires that
        // the requested transcript id belongs to that same student; any
        // other id is rejected with 403, so a student can no longer read
        // another student's transcript by changing the id.
        // ---------------------------------------------------------------
        public ActionResult Transcript(int? id)
        {
            var sid = SessionUser.GetStudentId(HttpContext);
            if (sid == null) return RedirectToAction("Login", "Account");

            int target = id ?? sid.Value;

            // Authentication is not authorization: verify object ownership,
            // consistent with TranscriptController.Details.
            if (sid.Value != target)
                return StatusCode(StatusCodes.Status403Forbidden, "No autorizado para ver este expediente.");

            var vm = new TranscriptService(db).Build(target);
            if (vm == null) return NotFound();

            ViewBag.SessionStudentId = sid.Value;
            return View(vm);
        }
    }
}
