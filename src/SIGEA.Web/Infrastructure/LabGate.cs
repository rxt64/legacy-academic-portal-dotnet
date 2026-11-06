using System.Configuration;
using System.Web;

namespace SIGEA.Web.Infrastructure
{
    /// <summary>
    /// Central gate for the vulnerability-lab routes.
    ///
    /// The labs are enabled only when the appSetting ENABLE_VULNERABILITY_LABS
    /// is exactly "true" (default false) AND the request arrives over loopback.
    /// RouteConfig does not even register the /lab routes unless
    /// <see cref="LabsConfigured"/> is true, so with the labs off those paths
    /// return 404. The environment/profile name alone never enables them.
    /// </summary>
    public static class LabGate
    {
        public const string Flag = "ENABLE_VULNERABILITY_LABS";

        /// <summary>True only if the appSetting flag is exactly "true".</summary>
        public static bool LabsConfigured
        {
            get
            {
                var v = ConfigurationManager.AppSettings[Flag];
                return string.Equals(v, "true", System.StringComparison.Ordinal);
            }
        }

        /// <summary>
        /// Effective enablement for a given request: configured AND loopback.
        /// Identity (loopback) comes from the server, not a parameter.
        /// </summary>
        public static bool IsEnabled(HttpRequestBase request)
        {
            return LabsConfigured && request != null && request.IsLocal;
        }
    }
}
