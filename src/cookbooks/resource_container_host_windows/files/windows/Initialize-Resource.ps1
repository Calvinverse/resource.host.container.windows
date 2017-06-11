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
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
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

function MachineIp
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

# -------------------------- Script start ------------------------------------

try
{
    $machineIp = MachineIp @commonParameterSwitches

    # Create 'client_connections.json' file that stores the connectivity for consul
    "{ `"advertise_addr`": `"$machineIp`", `"bind_addr`": `"$machineIp`" }"  | Out-File 'c:\meta\consul\client_connections.json'

    # Create 'client_connections.hcl' file that stores the connectivity for nomad
@"
bind_addr = `"$machineIp`"
advertise {
    http = \\"$machineIp\\"
    rpc = \\"$machineIp\\"
    serf = \\"$machineIp\\"
}
"@  | Out-File 'c:\meta\nomad\client_connections.hcl'

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

    Copy-Item -Path (Join-Path $dvdDriveLetter 'consul_client_location.json') -Destination 'c:\meta\consul\client_location.json'
    Copy-Item -Path (Join-Path $dvdDriveLetter 'consul_client_secrets.json') -Destination 'c:\meta\consul\client_secrets.json'

    Copy-Item -Path (Join-Path $dvdDriveLetter 'nomad_client_location.hcl') -Destination 'c:\meta\nomad\client_location.hcl'
    Copy-Item -Path (Join-Path $dvdDriveLetter 'nomad_client_secrets.hcl') -Destination 'c:\meta\nomad\client_secrets.hcl'

    # Copy the script that will be used to create the Doker network

    EnableAndStartService -serviceName 'consul'
    EnableAndStartService -serviceName 'nomad'
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
finally
{
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
