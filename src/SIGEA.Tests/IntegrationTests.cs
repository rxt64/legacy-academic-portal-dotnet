using System;
using System.Linq;
using SIGEA.Web.DAL;
using SIGEA.Web.Models;
using Xunit;

namespace SIGEA.Tests
{
    /// <summary>
    /// GROUP 1 - functional baseline against a LOCAL SQL Server created for
    /// this repository (schema + synthetic data applied). These tests are
    /// SKIPPED unless SIGEA_IT=1 and a reachable SchoolContext connection is
    /// configured (SIGEA_APP_PASSWORD). They must only run against local
    /// instances created for this lab.
    /// </summary>
    public class IntegrationTests
    {
        private static bool Enabled =>
            Environment.GetEnvironmentVariable("SIGEA_IT") == "1";

        [SkippableFact]
        public void DashboardCountsMatchBaseline()
        {
            Skip.IfNot(Enabled, "Set SIGEA_IT=1 with a local SIGEA database to run.");
            using (var db = new SchoolContext())
            {
                Assert.Equal(20, db.People.OfType<Student>().Count());
                Assert.Equal(6, db.People.OfType<Instructor>().Count());
                Assert.Equal(8, db.Courses.Count());
                Assert.Equal(4, db.Departments.Count());
                Assert.Equal(33, db.Enrollments.Count());
                Assert.Equal(1015000m, db.Departments.Sum(d => d.Budget));
            }
        }

        [SkippableFact]
        public void TranscriptOwnershipIsEnforcedByNormalPath()
        {
            Skip.IfNot(Enabled, "Set SIGEA_IT=1 with a local SIGEA database to run.");
            using (var db = new SchoolContext())
            {
                var svc = new TranscriptService(db);
                var ana = svc.Build(7);
                Assert.NotNull(ana);
                Assert.Equal(3, ana.Lines.Count); // Ana Mora has 3 enrollments
            }
        }
    }
}
