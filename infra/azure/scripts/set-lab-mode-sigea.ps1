<#
.SYNOPSIS
    Activa o desactiva temporalmente los laboratorios de seguridad (ENABLE_VULNERABILITY_LABS) en SIGEA por loopback.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [bool]$Enable,
    [string]$WebConfigPath = "C:\inetpub\sigea\Web.config",
    [string]$AppPoolName = "SigeaAppPool"
)

$ErrorActionPreference = "Stop"
[xml]$xml = Get-Content -Path $WebConfigPath -Encoding UTF8
$val = if ($Enable) { "true" } else { "false" }
foreach ($setting in $xml.configuration.appSettings.add) {
    if ($setting.key -eq "ENABLE_VULNERABILITY_LABS") {
        $setting.value = $val
    }
}
$xml.Save($WebConfigPath)
Import-Module WebAdministration
Restart-WebAppPool -Name $AppPoolName
Write-Host "==> ENABLE_VULNERABILITY_LABS establecido en '$val' y AppPool '$AppPoolName' reciclado."
