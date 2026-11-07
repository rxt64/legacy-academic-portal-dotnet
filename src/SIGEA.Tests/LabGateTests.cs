using System.Collections.Generic;
using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using SIGEA.Web.Infrastructure;
using Xunit;

namespace SIGEA.Tests
{
    // GROUP 2 - the vulnerability labs must be DISABLED BY DEFAULT.
    public class LabGateTests
    {
        private static IConfiguration Config(string flagValue)
        {
            var dict = new Dictionary<string, string>
            {
                [LabGate.Flag] = flagValue
            };
            return new ConfigurationBuilder().AddInMemoryCollection(dict).Build();
        }

        private static HttpRequest Request(bool isLocal)
        {
            var ctx = new DefaultHttpContext();
            ctx.Connection.RemoteIpAddress = isLocal ? IPAddress.Loopback : IPAddress.Parse("203.0.113.5");
            return ctx.Request;
        }

        [Fact]
        public void LabsConfigured_IsFalse_WhenFlagFalse()
        {
            var gate = new LabGate(Config("false"));
            Assert.False(gate.LabsConfigured);
        }

        [Fact]
        public void LabsConfigured_IsTrue_OnlyForExactTrue()
        {
            var wrongCase = new LabGate(Config("True")); // wrong case
            Assert.False(wrongCase.LabsConfigured);

            var exact = new LabGate(Config("true"));
            Assert.True(exact.LabsConfigured);
        }

        [Fact]
        public void IsEnabled_RequiresFlagAndLoopback()
        {
            var enabled = new LabGate(Config("true"));
            Assert.True(enabled.IsEnabled(Request(true)));    // loopback
            Assert.False(enabled.IsEnabled(Request(false)));  // non-loopback -> off

            var disabled = new LabGate(Config("false"));
            Assert.False(disabled.IsEnabled(Request(true)));  // flag off -> off
        }
    }
}
