<#
.SYNOPSIS
Starts the docker-1 workshop stack on Windows 11 Docker Desktop.

.DESCRIPTION
Detects a primary local IPv4 address (unless provided), sets required environment variables,
applies vm.max_map_count in the docker-desktop WSL VM, optionally runs `docker compose down`,
and starts the stack with `docker compose up -d`.

.PARAMETER DockerHostIP
Optional override for DOCKER_HOST_IP. If omitted, the primary IPv4 is auto-detected.

.PARAMETER PublicIP
Optional override for PUBLIC_IP. Defaults to DockerHostIP when omitted.

.PARAMETER NoDown
If set, skips `docker compose down` before startup.

.EXAMPLE
.\start-docker-1-win11.ps1

.EXAMPLE
.\start-docker-1-win11.ps1 -DockerHostIP 192.168.1.63 -PublicIP 192.168.1.63

.EXAMPLE
.\start-docker-1-win11.ps1 -NoDown
#>

param(
    [string]$DockerHostIP,
    [string]$PublicIP,
    [switch]$NoDown
)

$ErrorActionPreference = 'Stop'

function Get-PrimaryIPv4 {
    $defaultRoute = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' |
        Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
        Sort-Object RouteMetric, InterfaceMetric |
        Select-Object -First 1

    if (-not $defaultRoute) {
        throw 'No default IPv4 route found. Please pass -DockerHostIP explicitly.'
    }

    $address = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $defaultRoute.InterfaceIndex |
        Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } |
        Select-Object -First 1

    if (-not $address) {
        throw 'No suitable IPv4 address found on default interface. Please pass -DockerHostIP explicitly.'
    }

    return $address.IPAddress
}

Set-Location -Path $PSScriptRoot

try {
    docker info | Out-Null
}
catch {
    throw "Docker Desktop engine is not reachable. Start Docker Desktop and try again."
}

if (-not $DockerHostIP) {
    $DockerHostIP = Get-PrimaryIPv4
}

if (-not $PublicIP) {
    $PublicIP = $DockerHostIP
}

$env:DOCKER_HOST_IP = $DockerHostIP
$env:PUBLIC_IP = $PublicIP
$env:DATAPLATFORM_HOME = $PSScriptRoot

try {
    wsl -d docker-desktop -u root sysctl -w vm.max_map_count=262144
}
catch {
    Write-Warning "Could not set vm.max_map_count in docker-desktop WSL. Continuing startup."
}

if (-not $NoDown) {
    docker compose down
}

docker compose up -d
Write-Host "Use 'docker compose ps' to view the running containers status."
Write-Host "Using DOCKER_HOST_IP=$DockerHostIP"
Write-Host "Using PUBLIC_IP=$PublicIP"
Write-Host "Using DATAPLATFORM_HOME=$($env:DATAPLATFORM_HOME)"
