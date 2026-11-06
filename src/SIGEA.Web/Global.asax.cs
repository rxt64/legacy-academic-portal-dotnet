using System.Data.Entity;
using System.Web.Mvc;
using System.Web.Routing;
using SIGEA.Web.DAL;

namespace SIGEA.Web
{
    public class MvcApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            // The schema is owned by db/schema/01_schema.sql; EF must never
            // create or drop the database.
            Database.SetInitializer<SchoolContext>(null);

            AreaRegistration.RegisterAllAreas();
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
        }
    }
}
