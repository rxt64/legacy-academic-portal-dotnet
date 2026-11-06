using System.Linq;
using SIGEA.Web.Models;

namespace SIGEA.Web.DAL
{
    /// <summary>
    /// Builds a student's academic transcript. This is PURE data access with
    /// no authorization: callers are responsible for deciding whether the
    /// requester may see this student's record. The normal TranscriptController
    /// enforces ownership before calling here; the IDOR lab deliberately does
    /// not (see DOTNET-IDOR-01).
    /// </summary>
    public class TranscriptService
    {
        private readonly SchoolContext db;

        public TranscriptService(SchoolContext db) { this.db = db; }

        public TranscriptViewModel Build(int studentId)
        {
            var student = db.Students.Find(studentId);
            if (student == null) return null;

            var lines = db.Enrollments
                .Where(e => e.StudentID == studentId)
                .Select(e => new TranscriptLine
                {
                    CourseID = e.CourseID,
                    Title = e.Course.Title,
                    Credits = e.Course.Credits,
                    Grade = e.Grade
                })
                .OrderBy(l => l.Title)
                .ToList();

            var graded = lines.Where(l => l.Grade.HasValue).ToList();
            decimal? gpa = graded.Any() ? (decimal?)graded.Average(l => l.Grade.Value) : null;

            return new TranscriptViewModel
            {
                StudentID = studentId,
                StudentName = student.FullName,
                Lines = lines,
                Gpa = gpa,
                TotalCredits = lines.Sum(l => l.Credits)
            };
        }
    }
}
