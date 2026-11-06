using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;

namespace SIGEA.Web.DAL
{
    /// <summary>One row returned by the vulnerable academic search.</summary>
    public class LabStudentRow
    {
        public int ID { get; set; }
        public string LastName { get; set; }
        public string FirstName { get; set; }
        public string Email { get; set; }
        public string Discriminator { get; set; }
    }

    /// <summary>
    /// SECURITY-LAB: DOTNET-SQLI-01 — vulnerabilidad intencional para demostracion local.
    ///
    /// Deliberately vulnerable academic search. The user-controlled
    /// <paramref name="term"/> is concatenated straight into the SQL text and
    /// executed with a SqlCommand (no parameters). This is the artifact a
    /// security/modernization agent is expected to find.
    ///
    /// It runs over the SEPARATE, READ-ONLY connection "LabReadOnlyContext"
    /// (SQL login sigea_labro, SELECT only on synthetic data), so the exercise
    /// can only read synthetic rows and cannot modify anything.
    ///
    /// The future fix is to parameterize (SqlParameter / @term). DO NOT fix it
    /// in place; this is the before-state for the lab. The normal search in
    /// StudentsController is already parameterized (LINQ).
    /// </summary>
    public static class LabQueries
    {
        /// <summary>The raw SQL that will be sent, exposed so the lab page can show it.</summary>
        public static string BuildSql(string term)
        {
            // SECURITY-LAB DOTNET-SQLI-01: user input concatenated into SQL.
            return "SELECT ID, LastName, FirstName, Email, Discriminator " +
                   "FROM dbo.Person " +
                   "WHERE Discriminator = 'Student' AND LastName LIKE '%" + term + "%' " +
                   "ORDER BY LastName";
        }

        public static List<LabStudentRow> VulnerableSearch(string term)
        {
            var cs = ConfigurationManager.ConnectionStrings["LabReadOnlyContext"].ConnectionString;
            var rows = new List<LabStudentRow>();
            using (var conn = new SqlConnection(cs))
            {
                conn.Open();
                // SECURITY-LAB DOTNET-SQLI-01: concatenated text in a SqlCommand.
                using (var cmd = new SqlCommand(BuildSql(term), conn))
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
            return rows;
        }
    }
}
