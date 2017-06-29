<#
    .SYNOPSIS

    Configures the current resource.


    .DESCRIPTION
#>
[CmdletBinding()]
param(
)

$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $true;
        Debug = $false;
        ErrorAction = "Stop"
    }

# -------------------------- Script functions --------------------------------

function EnableAndStartService
{
    [CmdletBinding()]
    param(
        [string] $serviceName
    )

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    Set-Service `
        -Name $serviceName `
        -StartupType Automatic `
        @commonParameterSwitches

    $service = Get-Service -Name $serviceName @commonParameterSwitches
    if ($service.Status -ne 'Running')
    {
        Start-Service -Name $serviceName @commonParameterSwitches
    }
}

function Find-DvdDriveLetter
{
    [CmdletBinding()]
    param(
    )

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    try
    {
        $cd = Get-WMIObject -Class Win32_CDROMDrive -ErrorAction Stop
    }
    catch
    {
        Continue;
    }

    return $cd.Drive
}

function Get-MachineIp
{
    [CmdletBinding()]
    param(
    )

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    $result = ''
    $adapters = Get-NetAdapter @commonParameterSwitches
    foreach($adapter in $adapters)
    {
        if ($adapter.Status -ne 'Up')
        {
            continue
        }

        $address = Get-NetIPAddress -InterfaceAlias $adapter.InterfaceAlias |
            Where-Object { $_.AddressFamily -ne 'IPv6' }

        if (($address -ne $null) -and ($address -ne ''))
        {
            $result = $address.IPAddress
            break
        }
    }

    return $result
}

function New-DockerNetwork
{
    [CmdletBinding()]
    param(
        [string] $dvdDriveLetter
    )

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    # Set the docker network
}

function Set-DnsIpAddresses
{
    [CmdletBinding()]
    param(
    )

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    # Get all the physical network adapters that provide IPv4 services, are enabled and are the preferred network interface (because that's what acrylic will be
    # transmitting on).
    $adapter = Get-NetAdapter -Physical | Where-Object { Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -AddressState Preferred -ErrorAction SilentlyContinue }

    # Add the acrylic IP address to the list of DNS servers and make sure it's the first one so that it gets the first go at
    # resolving all the DNS queries.
    $localhost = '127.0.0.1'
    $serverDnsAddresses = @( $localhost )
    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $serverDnsAddresses -Verbose
}

# -------------------------- Script start ------------------------------------

try
{
    $machineIp = Get-MachineIp @commonParameterSwitches

    # Create 'client_connections.json' file that stores the connectivity for consul
    "{ `"advertise_addr`": `"$machineIp`", `"bind_addr`": `"$machineIp`" }"  | Out-File 'c:\meta\consul\client_connections.json' -Encoding ascii

    # Create 'client_connections.hcl' file that stores the connectivity for nomad
@"
bind_addr = "$machineIp"
advertise {
    http = "$machineIp"
    rpc = "$machineIp"
    serf = "$machineIp"
}
"@  | Out-File 'c:\meta\nomad\client_connections.hcl' -Encoding ascii

    # Find the CD
    $dvdDriveLetter = Find-DvdDriveLetter @commonParameterSwitches
    if (($dvdDriveLetter -eq $null) -or ($dvdDriveLetter -eq ''))
    {
        throw 'No DVD drive found'
    }

    # If the allow WinRM file is not there, disable WinRM in the firewall
    if (-not (Test-Path (Join-Path $dvdDriveLetter 'allow_winrm.json')))
    {
        # Disable WinRM in the firewall
    }

    Copy-Item -Path (Join-Path $dvdDriveLetter 'consul_client_location.json') -Destination 'c:\meta\consul\client_location.json' -Force @commonParameterSwitches
    Copy-Item -Path (Join-Path $dvdDriveLetter 'consul_client_secrets.json') -Destination 'c:\meta\consul\client_secrets.json' -Force @commonParameterSwitches

    Copy-Item -Path (Join-Path $dvdDriveLetter 'nomad_client_location.hcl') -Destination 'c:\meta\nomad\client_location.hcl' -Force @commonParameterSwitches
    Copy-Item -Path (Join-Path $dvdDriveLetter 'nomad_client_secrets.hcl') -Destination 'c:\meta\nomad\client_secrets.hcl' -Force @commonParameterSwitches

    Copy-Item -Path (Join-Path $dvdDriveLetter 'unbound\unbound_zones.conf') -Destination 'c:\meta\unbound\unbound_zones.conf' -Force @commonParameterSwitches

    Set-DnsIpAddresses @commonParameterSwitches

    New-DockerNetwork -dvdDriveLetter $dvdDriveLetter @commonParameterSwitches

    EnableAndStartService -serviceName 'consul' @commonParameterSwitches
    EnableAndStartService -serviceName 'unbound' @commonParameterSwitches
    EnableAndStartService -serviceName 'nomad' @commonParameterSwitches

    try
    {
        Set-Service `
            -Name 'Provisioning' `
            -StartupType Disabled `
            @commonParameterSwitches

        Stop-Service `
            -Name 'Provisioning' `
            -NoWait `
            -Force `
            @commonParameterSwitches
    }
    catch
    {
        Write-Error "Failed to stop the service. Error was $($_.Exception.ToString())"
    }
}
catch
{
    $ErrorRecord=$Error[0]
    $ErrorRecord | Format-List * -Force
    $ErrorRecord.InvocationInfo |Format-List *
    $Exception = $ErrorRecord.Exception
    for ($i = 0; $Exception; $i++, ($Exception = $Exception.InnerException))
    {
        "$i" * 80
        $Exception |Format-List * -Force
    }
}
