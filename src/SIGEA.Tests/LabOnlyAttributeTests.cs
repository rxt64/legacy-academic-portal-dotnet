using System.Collections.Generic;
using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SIGEA.Web.Infrastructure;
using Xunit;

namespace SIGEA.Tests
{
    // GROUP 2 - the [LabOnly] filter makes lab actions behave as 404 when the
    // labs are not enabled for the request.
    public class LabOnlyAttributeTests
    {
        private static ActionExecutingContext Ctx(bool isLocal, string flagValue)
        {
            var config = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string> { [LabGate.Flag] = flagValue })
                .Build();

            var services = new ServiceCollection();
            services.AddSingleton<LabGate>(new LabGate(config));
            var provider = services.BuildServiceProvider();

            var httpContext = new DefaultHttpContext { RequestServices = provider };
            httpContext.Connection.RemoteIpAddress = isLocal ? IPAddress.Loopback : IPAddress.Parse("203.0.113.5");

            var actionContext = new ActionContext(httpContext, new RouteData(), new ActionDescriptor());

            return new ActionExecutingContext(
                actionContext,
                new List<IFilterMetadata>(),
                new Dictionary<string, object>(),
                controller: new object());
        }

        [Fact]
        public void ReturnsNotFound_WhenFlagOff()
        {
            var ctx = Ctx(isLocal: true, flagValue: "false");
            new LabOnlyAttribute().OnActionExecuting(ctx);
            Assert.IsType<Microsoft.AspNetCore.Mvc.NotFoundResult>(ctx.Result);
        }

        [Fact]
        public void ReturnsNotFound_WhenNonLoopback_EvenIfFlagOn()
        {
            var ctx = Ctx(isLocal: false, flagValue: "true");
            new LabOnlyAttribute().OnActionExecuting(ctx);
            Assert.IsType<Microsoft.AspNetCore.Mvc.NotFoundResult>(ctx.Result);
        }

        [Fact]
        public void AllowsThrough_WhenEnabledAndLoopback()
        {
            var ctx = Ctx(isLocal: true, flagValue: "true");
            new LabOnlyAttribute().OnActionExecuting(ctx);
            Assert.Null(ctx.Result); // not short-circuited
        }
    }
}
