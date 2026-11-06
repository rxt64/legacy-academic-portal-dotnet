using System.Web;

namespace SIGEA.Web.Infrastructure
{
    /// <summary>
    /// Minimal session-backed identity for the lab. A "login" stores the
    /// authenticated student's ID in session; it is read from the session,
    /// never from a request parameter, so authentication cannot be spoofed by
    /// tampering with a query string.
    /// </summary>
    public static class SessionUser
    {
        public const string StudentIdKey = "StudentID";
        public const string StudentNameKey = "StudentName";

        public static int? GetStudentId(HttpContextBase ctx)
        {
            var v = ctx?.Session?[StudentIdKey];
            return v == null ? (int?)null : (int)v;
        }

        public static string GetStudentName(HttpContextBase ctx)
        {
            return ctx?.Session?[StudentNameKey] as string;
        }

        public static bool IsAuthenticated(HttpContextBase ctx)
        {
            return GetStudentId(ctx).HasValue;
        }

        public static void SignIn(HttpContextBase ctx, int studentId, string studentName)
        {
            ctx.Session[StudentIdKey] = studentId;
            ctx.Session[StudentNameKey] = studentName;
        }

        public static void SignOut(HttpContextBase ctx)
        {
            ctx.Session.Remove(StudentIdKey);
            ctx.Session.Remove(StudentNameKey);
        }
    }
}
