using System.Web.Mvc;
using System.Web.Routing;

namespace SIGEA.Web
{
    public class RouteConfig
    {
        public static void RegisterRoutes(RouteCollection routes)
        {
            routes.IgnoreRoute("{resource}.axd/{*pathInfo}");

            // Normal screens. The Lab controller is reachable by the default
            // route as well, but every lab action carries [LabOnly], which
            // returns 404 unless the labs are enabled AND the caller is on
            // loopback. See Infrastructure/LabGate + LabOnlyAttribute.
            routes.MapRoute(
                name: "Default",
                url: "{controller}/{action}/{id}",
                defaults: new { controller = "Home", action = "Index", id = UrlParameter.Optional }
            );
        }
    }
}
