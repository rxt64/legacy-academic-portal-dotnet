using System.Configuration;
using System.Web;
using Moq;
using SIGEA.Web.Infrastructure;
using Xunit;

namespace SIGEA.Tests
{
    // GROUP 2 - the vulnerability labs must be DISABLED BY DEFAULT.
    [Collection("LabGateConfig")]
    public class LabGateTests
    {
        private static HttpRequestBase Request(bool isLocal)
        {
            var req = new Mock<HttpRequestBase>();
            req.SetupGet(r => r.IsLocal).Returns(isLocal);
            return req.Object;
        }

        [Fact]
        public void LabsConfigured_IsFalse_WhenFlagFalse()
        {
            ConfigurationManager.AppSettings[LabGate.Flag] = "false";
            Assert.False(LabGate.LabsConfigured);
        }

        [Fact]
        public void LabsConfigured_IsTrue_OnlyForExactTrue()
        {
            ConfigurationManager.AppSettings[LabGate.Flag] = "True"; // wrong case
            Assert.False(LabGate.LabsConfigured);
            ConfigurationManager.AppSettings[LabGate.Flag] = "true";
            Assert.True(LabGate.LabsConfigured);
        }

        [Fact]
        public void IsEnabled_RequiresFlagAndLoopback()
        {
            ConfigurationManager.AppSettings[LabGate.Flag] = "true";
            Assert.True(LabGate.IsEnabled(Request(true)));    // loopback
            Assert.False(LabGate.IsEnabled(Request(false)));  // non-loopback -> off

            ConfigurationManager.AppSettings[LabGate.Flag] = "false";
            Assert.False(LabGate.IsEnabled(Request(true)));   // flag off -> off
        }
    }
}
