using System.Web.Mvc;

namespace SIGEA.Web.Infrastructure
{
    /// <summary>
    /// Action filter that makes an action behave as if it did not exist
    /// (HTTP 404) whenever the labs are not enabled for the current request
    /// (flag off, or non-loopback caller). Applied to the lab controller as a
    /// defense-in-depth layer on top of the route not being registered.
    /// </summary>
    public class LabOnlyAttribute : ActionFilterAttribute
    {
        public override void OnActionExecuting(ActionExecutingContext filterContext)
        {
            var request = filterContext.HttpContext.Request;
            if (!LabGate.IsEnabled(request))
            {
                filterContext.Result = new HttpNotFoundResult();
            }
        }
    }
}
