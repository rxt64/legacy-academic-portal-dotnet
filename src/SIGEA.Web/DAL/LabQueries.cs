using System.Collections.Generic;
using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace SIGEA.Web.DAL
{
    /// <summary>One row returned by the academic search.</summary>
    public class LabStudentRow
    {
        public int ID { get; set; }
        public string LastName { get; set; }
        public string FirstName { get; set; }
        public string Email { get; set; }
        public string Discriminator { get; set; }
    }

    /// <summary>
    /// SECURITY-LAB: DOTNET-SQLI-01 — remediated.
    ///
    /// The academic search previously concatenated the user-controlled
    /// <c>term</c> directly into the SQL text (CWE-89). It now uses a
    /// parameterized <see cref="SqlCommand"/> (<c>@term</c>), so injection
    /// metacharacters in <c>term</c> are always treated as literal text,
    /// never as SQL syntax.
    ///
    /// It runs over the SEPARATE, READ-ONLY connection "LabReadOnlyContext"
    /// (SQL login sigea_labro, SELECT only on synthetic data), so the exercise
    /// can only read synthetic rows and cannot modify anything.
    ///
    /// The normal search in StudentsController is already parameterized (LINQ).
    /// </summary>
    public static class LabQueries
    {
        /// <summary>The parameterized SQL that will be sent, exposed so the lab page can show it.</summary>
        public static string BuildSql()
        {
            return "SELECT ID, LastName, FirstName, Email, Discriminator " +
                   "FROM dbo.Person " +
                   "WHERE Discriminator = 'Student' AND LastName LIKE @term " +
                   "ORDER BY LastName";
        }

        /// <summary>
        /// Back-compat overload kept for callers/tests that pass the search
        /// term: the SQL text itself no longer depends on
        /// <paramref name="term"/> because the value is bound through a
        /// SqlParameter (@term), not concatenated into the command text.
        /// </summary>
        public static string BuildSql(string term) => BuildSql();

        public static List<LabStudentRow> SafeParameterizedSearch(string connectionString, string term)
        {
            var rows = new List<LabStudentRow>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                using (var cmd = new SqlCommand(BuildSql(), conn))
                {
                    cmd.Parameters.Add(new SqlParameter("@term", SqlDbType.NVarChar, 100)
                    {
                        Value = "%" + (term ?? string.Empty).Trim() + "%"
                    });
                    using (var r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            rows.Add(new LabStudentRow
                            {
                                ID = r.GetInt32(0),
                                LastName = r.IsDBNull(1) ? null : r.GetString(1),
                                FirstName = r.IsDBNull(2) ? null : r.GetString(2),
                                Email = r.IsDBNull(3) ? null : r.GetString(3),
                                Discriminator = r.IsDBNull(4) ? null : r.GetString(4)
                            });
                        }
                    }
                }
            }
            return rows;
        }

        public static List<LabStudentRow> VulnerableSearch(string term, IConfiguration configuration)
        {
            var cs = SchoolContext.ResolveConnectionString(configuration, "LabReadOnlyContext");
            return SafeParameterizedSearch(cs, term);
        }
    }
}
