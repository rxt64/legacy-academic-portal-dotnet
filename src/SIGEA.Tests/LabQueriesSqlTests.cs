using SIGEA.Web.DAL;
using Xunit;

namespace SIGEA.Tests
{
    // GROUP 3 (optional characterization, offline/string-level) - documents
    // the DOTNET-SQLI-01 anti-pattern without asserting the app is "safe".
    public class LabQueriesSqlTests
    {
        [Fact]
        public void UserInputIsConcatenatedVerbatim()
        {
            var sql = LabQueries.BuildSql("mora");
            Assert.Contains("LIKE '%mora%'", sql);
        }

        [Fact]
        public void InjectionMetacharactersAreNotNeutralised()
        {
            var sql = LabQueries.BuildSql("x%' OR '1'='1' --");
            Assert.Contains("x%' OR '1'='1' --", sql);
            Assert.DoesNotContain("@", sql); // no parameter placeholder used
        }
    }
}
