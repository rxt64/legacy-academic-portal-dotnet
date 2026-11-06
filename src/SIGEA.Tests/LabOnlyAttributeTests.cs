using System.Configuration;
using System.Web;
using System.Web.Mvc;
using System.Web.Routing;
using Moq;
using SIGEA.Web.Infrastructure;
using Xunit;

namespace SIGEA.Tests
{
    // GROUP 2 - the [LabOnly] filter makes lab actions behave as 404 when the
    // labs are not enabled for the request.
    [Collection("LabGateConfig")]
    public class LabOnlyAttributeTests
    {
        private static ActionExecutingContext Ctx(bool isLocal)
        {
            var request = new Mock<HttpRequestBase>();
            request.SetupGet(r => r.IsLocal).Returns(isLocal);
            var http = new Mock<HttpContextBase>();
            http.SetupGet(c => c.Request).Returns(request.Object);

            var ctx = new ActionExecutingContext
            {
                HttpContext = http.Object,
                RouteData = new RouteData(),
                ActionDescriptor = new Mock<ActionDescriptor>().Object
            };
            return ctx;
        }

        [Fact]
        public void ReturnsNotFound_WhenFlagOff()
        {
            ConfigurationManager.AppSettings[LabGate.Flag] = "false";
            var ctx = Ctx(true);
            new LabOnlyAttribute().OnActionExecuting(ctx);
            Assert.IsType<HttpNotFoundResult>(ctx.Result);
        }

        [Fact]
        public void ReturnsNotFound_WhenNonLoopback_EvenIfFlagOn()
        {
            ConfigurationManager.AppSettings[LabGate.Flag] = "true";
            var ctx = Ctx(false);
            new LabOnlyAttribute().OnActionExecuting(ctx);
            Assert.IsType<HttpNotFoundResult>(ctx.Result);
        }

        [Fact]
        public void AllowsThrough_WhenEnabledAndLoopback()
        {
            ConfigurationManager.AppSettings[LabGate.Flag] = "true";
            var ctx = Ctx(true);
            new LabOnlyAttribute().OnActionExecuting(ctx);
            Assert.Null(ctx.Result); // not short-circuited
        }
    }
}
