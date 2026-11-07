using SIGEA.Web.DAL;
using Xunit;

namespace SIGEA.Tests
{
    // GROUP 3 (offline, string-level) - confirms the DOTNET-SQLI-01 remediation:
    // the SQL text uses a bound @term parameter and never embeds user input.
    public class LabQueriesSqlTests
    {
        [Fact]
        public void SqlUsesParameterPlaceholder_NotConcatenation()
        {
            var sql = LabQueries.BuildSql();
            Assert.Contains("LIKE @term", sql);
            Assert.DoesNotContain("LIKE '%", sql);
        }

        [Fact]
        public void InjectionMetacharactersNeverReachTheSqlText()
        {
            // The SQL text is identical no matter what the caller searches for,
            // because the term is bound through SqlParameter (@term) rather than
            // concatenated into the command text.
            var baseline = LabQueries.BuildSql();
            var withOrdinaryTerm = LabQueries.BuildSql("mora");
            var withInjectionPayload = LabQueries.BuildSql("x%' OR '1'='1' --");

            Assert.Equal(baseline, withOrdinaryTerm);
            Assert.Equal(baseline, withInjectionPayload);
            Assert.DoesNotContain("OR '1'='1'", withInjectionPayload);
        }
    }
}
