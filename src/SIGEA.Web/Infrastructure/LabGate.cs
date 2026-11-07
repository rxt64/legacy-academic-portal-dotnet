using System;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;

namespace SIGEA.Web.Infrastructure
{
    /// <summary>
    /// Central gate for the vulnerability-lab routes.
    ///
    /// The labs are enabled only when the appSetting ENABLE_VULNERABILITY_LABS
    /// is exactly "true" (default false) AND the request arrives over loopback.
    /// <see cref="LabOnlyAttribute"/> returns 404 for lab actions unless the
    /// labs are enabled AND the caller is on loopback. The environment/profile
    /// name alone never enables them.
    /// </summary>
    public class LabGate
    {
        public const string Flag = "ENABLE_VULNERABILITY_LABS";

        private readonly IConfiguration _configuration;

        public LabGate(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        /// <summary>True only if the appSetting flag is exactly "true".</summary>
        public bool LabsConfigured
        {
            get
            {
                var v = _configuration[Flag];
                return string.Equals(v, "true", StringComparison.Ordinal);
            }
        }

        /// <summary>
        /// Effective enablement for a given request: configured AND loopback.
        /// Identity (loopback) comes from the server, not a parameter.
        /// </summary>
        public bool IsEnabled(HttpRequest request)
        {
            return LabsConfigured && request != null && IsLocal(request);
        }

        private static bool IsLocal(HttpRequest request)
        {
            var connection = request.HttpContext.Connection;
            if (connection.RemoteIpAddress == null)
            {
                return true; // e.g. TestServer / in-memory requests with no transport.
            }

            if (connection.LocalIpAddress != null)
            {
                return connection.RemoteIpAddress.Equals(connection.LocalIpAddress);
            }

            return System.Net.IPAddress.IsLoopback(connection.RemoteIpAddress);
        }
    }
}
