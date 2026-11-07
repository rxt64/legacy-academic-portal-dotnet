using Microsoft.AspNetCore.Http;

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

        public static int? GetStudentId(HttpContext ctx)
        {
            return ctx?.Session?.GetInt32(StudentIdKey);
        }

        public static string GetStudentName(HttpContext ctx)
        {
            return ctx?.Session?.GetString(StudentNameKey);
        }

        public static bool IsAuthenticated(HttpContext ctx)
        {
            return GetStudentId(ctx).HasValue;
        }

        public static void SignIn(HttpContext ctx, int studentId, string studentName)
        {
            ctx.Session.SetInt32(StudentIdKey, studentId);
            ctx.Session.SetString(StudentNameKey, studentName ?? string.Empty);
        }

        public static void SignOut(HttpContext ctx)
        {
            ctx.Session.Remove(StudentIdKey);
            ctx.Session.Remove(StudentNameKey);
        }
    }
}
