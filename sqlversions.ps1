#Requires -Version 3

#------------------------------------------------------------------------------
# NAME     : sqlversions.ps1
#
# PURPOSE  : Creates SQL Server groups within Turbonomic
#
# AUTHOR   : R.A. Stern
# EMAIL    : richard.stern@turbonomic.com
# CREATED  : 2018.10.05
# MODIFIED : 2018.10.10
# VERSION  : 1.0.0
#
#------------------------------------------------------------------------------

<#
    .SYNOPSIS
      Creates groups of SQL Server VMs.

    .DESCRIPTION
      Creates groups of SQL Server VMs within Turbonomic based on the server
      version number, or other user-defined grouping criteria.

    .PARAMETER ServerName
      Hostname or IP address of the Turbonomic server

    .PARAMETER Credential
      PSCredential object for Turbonomic

      Note:
        If you do not supply a Credential, or Username and Password, you will be
        prompted for credentials

    .PARAMETER Username
      Turbonomic username

    .PARAMETER Password
      Turbonomic password

    .PARAMETER SourceGroup
      Name of the Turbonomic group to use for VMs to query

    .PARAMETER SQLGroups
      Hashtable of groups to create, and their filters. By default the script
      will create one group for all SQL 2008 and one for SQL 200 8R2 VMs.

      Note:
        VMs with multiple instances will be placed in all applicable groups.

    .PARAMETER GroupAppend
      If a Turbonomic group already exists, VMs will be added to it.

    .PARAMETER GroupClobber
      If a Turbonomic group already exists, it will be replaced.
      GroupAppend takes priority of both supplied.

    .PARAMETER OutFile
      Output file for CSV export of SQL VM instance data

    .PARAMETER DisableSMO
      Disables SQL Server Management Objects (SMO) lookup method

    .PARAMETER DisableWMI
      Disables Windows Management Instrumentation (WMI) lookup method

    .PARAMETER DisableWinRM
      Disables WinRM (WSMAN) remoting lookup method

    .PARAMETER DisableRegistry
      Disables Remote registry lookup method

    .EXAMPLE
     .\sqlversions.ps1 -Host 10.10.1.100 -SourceGroup "Windows VMs"
     Basic call with minimum required parameters.

    .EXAMPLE
      .\sqlversions.ps1 -Host 10.10.1.100 -Username administrator -SourceGroup "Windows VMs"
      Specifies the Turbonomic user as 'administrator'

    .EXAMPLE
      .\sqlversions.ps1 -Host 10.10.1.100 -SourceGroup "Windows VMs" -OutFile "C:\versions.csv" -GroupClobber
      Will replace existing group members, if they exist, with discovered members and set the CSV output to an
      alternate location.

    .EXAMPLE
      .\sqlversions.ps1 -Host 10.10.1.100 -SourceGroup "Windows VMs" -DisableSMO -DisableWMI
      Disables all WMI calls. This will speed up the script if the environment does not support SMO or basic WMI.

    .NOTES
      - If all methods are disabled, no lookup can be performed.
      - You will be prompted for all required vCenter credentials.
      - PowerCLI, and .Net 4.5 or higher must be installed.
      - To use SMO, both the target(s) VM and the VM this script runs on must have
        SMO libraries installed.
      - To use WinRM the target machine(s) must have WSMAN configured.
      - To use WMI the target machine(s) must have RPC enabled.
      - Remote connections are made using the script caller's credentials, thus
        the caller must be a user with sufficient rights to access the target
        VMs using the desired methods.
#>

[CmdletBinding()]
param(
    [parameter(HelpMessage = 'Host name or address [localhost]')]
    [alias('Server', 'Host')]
    [string] $ServerName = 'localhost',

    [parameter(HelpMessage = 'PSCredential for Turbonomic Instance')]
    [alias('Cred')]
    [System.Management.Automation.PSCredential] $Credential,

    [parameter(HelpMessage = 'Username [administrator]')]
    [alias('User')]
    [string] $Username = 'administrator',

    [parameter(HelpMessage = 'Password')]
    [alias('Pass')]
    [string] $Password,

    [parameter(HelpMessage = 'Application Source Group Name')]
    [string] $SourceGroup,

    [parameter(HelpMessage = 'SQL Grouping Object')]
    [hashtable] $SQLGroups,

    [parameter(HelpMessage = 'Will attempt to append group members if a destination group already exists')]
    [switch] $GroupAppend = $false,

    [parameter(HelpMessage = 'Destroy any existing destination group')]
    [switch] $GroupClobber = $false,

    [parameter(HelpMessage = 'Output CSV file [.\sqlversions.csv]')]
    [string] $OutputFile = 'sql_vms.csv',

    [parameter(HelpMessage = 'Specifies an SMO Management Server')]
    [string] $SMOServer = $null,

    [parameter(HelpMessage = 'Disables SMO connections')]
    [switch] $DisableSMO = $false,

    [parameter(HelpMessage = 'Disables Remote Registry connections')]
    [switch] $DisableRegistry = $false,

    [parameter(HelpMessage = 'Disables WMI connections')]
    [switch] $DisableWMI = $false,

    [parameter(HelpMessage = 'Disables WinRM connections')]
    [switch] $DisableWinRM = $false
)


# Error handling
$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

# Turbonomic settings
$vmtAppFilter = $true
$vmtCredential = $null
$vmtProtocol = 'https'
$vmtBaseUrl = '/vmturbo/rest'
$vmtDisableHateoas = $true
$vmtHeaders = @{}
$vmtContentType = 'application/json'

if ($SQLGroups)
{ $vmtSqlGroups = $SQLGroups }
else
{
    $vmtSqlGroups = @{
        '2008'   = @{ name = 'SQL2008'; match = '10\.[0-4]{1}.*'; matchProperty = 'versionNumber' }
        '2008R2' = @{ name = 'SQL2008R2'; match = '10\.5.*'; matchProperty = 'versionNumber' }
    }
}

# vCenter settings
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null

$vcServer = $null
$vcTargets = @{}

# SQL Server discovery
$regSQLRoot = "SOFTWARE\\Microsoft\\Microsoft SQL Server"
$sqlMethods = [ordered]@{
    'SMO'        = 'Get-SQLBySMO'
    'WMI'        = 'Get-SQLByWMI'
    'WinRM'      = 'Get-SQLByWinRM'
    'Registry'   = 'Get-SQLByReg'
}


if (!$DisableSMO)
{
    if ([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") -eq $null)
    { $DisableSMO = $true }
}



if (-not("sslskip" -as [type]))
{
    Add-Type -TypeDefinition @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public static class sslskip {
    public static bool ReturnTrue(object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors) { return true; }

    public static RemoteCertificateValidationCallback GetDelegate() {
        return new RemoteCertificateValidationCallback(sslskip.ReturnTrue);
    }
}
"@
}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [sslskip]::GetDelegate()

if (-not ([Net.ServicePointManager]::SecurityProtocol).ToString().Contains([Net.SecurityProtocolType]::Tls12))
{
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol.toString() + ', ' + [Net.SecurityProtocolType]::Tls12
}


#
# Generic facilities
#
function Get-VCenterCreds ($list)
{
    $vc = @{}

    foreach ($vm in $list)
    {
        $key = $vm.discoveredby.displayName

        if ($key -and !$vc.Contains($key))
        {
            $creds = Get-Credential -Message "Please provide credentials for the vCenter: $key"
            $vc.Add($key, $creds)
        }
    }

    $vc
}


#
# Turbonomic facilities
#
function Get-TurbonomicLogin ($cred, $user, $pass)
{
    if ($cred)
    { $cred }
    elseif ($pass)
    {
        $secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
        New-Object System.Management.Automation.PSCredential ($user, $secpasswd)
    }
    else
    { Get-Credential -Message 'Please enter your Turbonomic credentials' }
}

function ConvertTo-BasicAuth
{
    param (
        [System.Management.Automation.PSCredential] $Credential
    )

    $AuthString = "{0}:{1}" -f $Credential.UserName, $Credential.GetNetworkCredential().password
    $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)

    [Convert]::ToBase64String($AuthBytes)
}


function Invoke-TurboRequest
{
    param (
        [string] $Method = 'Get',
        [string] $Protocol = $Script:vmtProtocol,
        [string] $Server = $Script:ServerName,
        [hashtable] $Headers = $Script:vmtHeaders,
        [string] $BaseUrl = $Script:vmtBaseUrl,
        [string] $ContentType = $Script:vmtContentType,
        [string] $Url,
        $Body
    )

    $uri = "{0}://{1}{2}/{3}" -f $Protocol, $Server, $BaseUrl, $Url

    if ($vmtDisableHateoas -and !($Method.ToLower() -in ('put', 'post')))
    {
        $uri += if ($uri -contains '&') { '&' } else { '?' }
        $uri += 'disable_hateoas=true'
    }

    Write-Verbose "Body: $Body"
    Invoke-RestMethod -Method $Method -Uri $uri -Headers $Headers -Body $Body -ContentType $ContentType
}


function Invoke-TurboSession
{
    try
    {
        $auth = ConvertTo-BasicAuth $Script:vmtCredential
        $Script:vmtHeaders = @{'Authorization' = "Basic $auth"; 'Accept' = 'application/json'}
        $response = Invoke-TurboRequest -Url 'admin/versions' | Out-Null
        $true
    }
    catch
    {
        Write-Output $_.Exception
        $false
    }
}


function Get-TurboEntityUuidByName
{
    param (
        [string] $Name,
        [string] $EntityType,
        [string] $Scope = 'Market'
    )

    $search = ''

    if (![string]::IsNullOrEmpty($Name))
    { $search += "&q=$Name" }

    if (![string]::IsNullOrEmpty($EntityType))
    { $search += "&types=$EntityType" }

    if (![string]::IsNullOrEmpty($Scope))
    { $search += "&scope=$Scope" }

    (Invoke-TurboRequest -Url ('search?' + $search.Substring(1))).uuid
}


function Get-TurboGroupMembers
{
    param (
        [string] $Name,
        [string] $Uuid
    )
    if (![string]::IsNullOrEmpty($Name))
    { $Uuid = Get-TurboEntityUuidByName $Name 'Group' }

    Invoke-TurboRequest -Url "groups/$Uuid/members"
}


function Update-TurboGroupMembers
{
    param(
        [string] $GroupName,
        [string] $GroupUuid,
        [Parameter(ValueFromPipeline = $true)]
        [string[]] $MemberList,
        [string] $GroupType = 'VirtualMachine'
    )

    begin
    {
        $members = [System.Collections.ArrayList]@()

        if ([string]::IsNullOrEmpty($GroupUuid))
        { $GroupUuid = Get-TurboEntityUuidByname $GroupName 'Group' }
    }

    process
    {
        $MemberList | % { $members.Add($_) | Out-Null }
    }

    end
    {
        if ($members.Count -lt 1)
        {
            Write-Verbose "No group members provided"
            return $false
        }

        if (![string]::IsNullOrEmpty($GroupUuid))
        {
            if ($GroupAppend)
            {
              Write-Verbose "Appending members to group"
              $old_members = Get-TurboGroupMembers -Uuid $GroupUuid | % { $_.uuid }
              $members += $old_members
            }
            elseif (!$GroupClobber)
            {
                Write-Warning "Unable to create group [$GroupName]: Group already exists"
                Write-Warning "Use the -GroupClobber option to force group overwriting"
                return
            }

            $method = 'Put'
            $url = 'groups/{0}' -f $GroupUuid
        }
        else
        {
            $method = 'Post'
            $url = 'groups'
        }

        $groupHash = @{"displayName" = $GroupName;
                       "groupType" = $GroupType;
                       "isStatic" = $true;
                       "memberUuidList" = @($members | select -Unique)
                      }

        $dto = ConvertTo-Json $groupHash -Depth 10

        Invoke-TurboRequest -Method $method -Url $url -Body $dto
    }
}


function Create-TurboGroups
{
    param (
      [array] $Data,
      [hashtable] $GroupMap
    )

    $pbActivity = "Creating Turbonomic groups"
    $prog = 0
    Write-Progress -Id 1 -Activity $pbActivity

    foreach ($key in $GroupMap.Keys)
    {
        $group = $GroupMap[$key]
        Write-Progress -Id 1 -Activity $pbActivity -Status $group.name -PercentComplete (($prog / $GroupMap.Count) * 100)

        try
        {
            $Data | ? { $_.($group.matchProperty) -match $group.match } |
              % { $_.vmtUuid } |
              Update-TurboGroupMembers -GroupName $group.name | Out-Null
        }
        catch
        {
            Write-Output "Error creating group [$($group.name)]"
            Write-Output $_.Exception
        }

        $prog += 1
    }

    Write-Progress -Id 1 -Activity $pbActivity -Completed
}


#
# vCenter facilities
#
function Get-vcVMHostNameAndIP
{
    param (
        [string] $Hostname,
        [string] $Id
    )

    $v = Get-VM -Name "$Hostname" | ? { $_.Id.Contains("$Id") } | Get-View
    $name = $v.Guest.HostName
    $ip = $v.Guest.IPAddress | ? { $_ -ne "localhost" -and $_ -ne "127.*" } | select -First 1

    $name,$ip
}


function Connect-vcVCenter
{
    param (
        [string] $Server,
        [System.Management.Automation.PSCredential] $Credential
    )

    Connect-VIServer -Server $Server -User $Credential.UserName -Password $Credential.GetNetworkCredential().password -Force | Out-Null
    $Script:vcServer = $Server
}


function Disconnect-vcVCenter
{
    param (
      [string] $Server = $Script:vcServer
    )

    Disconnect-VIServer -Server $Server -Confirm:$false
}


#
# Audit facilities
#
function ConvertTo-SQLDateVersion
{
    param (
        [string] $Version
    )

    switch -regex ($Version)
    {
        '15\..*'         { "SQL Server 2019"; break }
        '14\..*'         { "SQL Server 2017"; break }
        '13\..*'         { "SQL Server 2016"; break }
        '12\..*'         { "SQL Server 2014"; break }
        '11\..*'         { "SQL Server 2012"; break }
        '10\.5.*'       { "SQL Server 2008 R2"; break }
        '10\.[0-4]{1}.*' { "SQL Server 2008"; break }
        '9\..*'          { "SQL Server 2005"; break }
        '8\..*'          { "SQL Server 2000"; break }
        default          { "Unkown Version"; break }
    }
}


function New-SQLVersion
{
    $obj = New-Object PSObject

    $obj.PSObject.TypeNames.Insert(0, "SQLVersion")
    $obj | Add-Member -MemberType NoteProperty -Name host -Value ''
    $obj | Add-Member -MemberType NoteProperty -Name instanceName -Value ''
    $obj | Add-Member -MemberType NoteProperty -Name instanceId -Value ''
    $obj | Add-Member -MemberType NoteProperty -Name versionNumber -Value ''
    $obj | Add-Member -MemberType NoteProperty -Name version -Value ''
    $obj | Add-Member -MemberType NoteProperty -Name edition -Value ''
    $obj | Add-Member -MemberType NoteProperty -Name serviceState -Value ''
    $obj | Add-Member -MemberType NoteProperty -Name vmtUuid -Value ''
    $obj | Add-Member -MemberType NoteProperty -name method -Value ''

    $obj
}


# SMO (WMI) is preferred
function Get-SQLBySMO
{
    param (
        [string] $Hostname,
        [string] $Uuid
    )

    $inst = @()
    $smo = New-Object 'Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer' $Hostname
    $services = $smo.Services | ? { $_.type -eq "SqlServer" }

    foreach ($s in $services)
    {
        $ap = $s.AdvancedProperties

        $sql = New-SQLVersion
        $sql.method = 'SMO'
        $sql.host = $Hostname
        $sql.vmtUuid = $Uuid
        $sql.instanceName = if ($s.Name.Contains('$')) { $s.Name.split('$')[1] } else { $s.Name }
        $sql.instanceId = ($ap | ? { $_.Name -eq "INSTANCEID" }).Value
        $sql.versionNumber = ($ap | ? { $_.Name -eq "VERSION" }).Value
        $sql.version = ConvertTo-SQLDateVersion $sql.versionNumber
        $sql.edition = ($ap | ? { $_.Name -eq "SKUNAME" }).Value
        $sql.serviceState = $s.ServiceState
        $inst += $sql
    }

    $inst
}


# WMI services call
function Get-SQLByWMI
{
    param (
        [string] $Hostname,
        [string] $Uuid
    )

    $inst = @()
    $cms = gwmi -ComputerName $Hostname -Namespace "root\Microsoft\SqlServer" -Class "__Namespace" | ? { $_.Name -like "ComputerManagement*" } | select Name

    foreach ($cm in $cms)
    {
        $prop = gwmi -ComputerName $Hostname -Namespace "root\Microsoft\SqlServer\$($cm.Name)" -Class "SqlServiceAdvancedProperty" | ? { $_.ServiceName -eq "MSSQLSERVER" -or $_.ServiceName -like "MSSQL$*" }
        $services = $prop | ? { $_.ServiceName } | select ServiceName -Unique

        foreach ($s in $services)
        {
            $name = if ($s.ServiceName.Contains('$')) { $s.ServiceName.split('$')[1] } else { $s.ServiceName }

            if ($name -in ($inst | % { $_.instanceName }))
            { continue }

            $properties = $prop | ? { $_.ServiceName -eq $s.ServiceName -and $_.PropertyName -in ('INSTANCEID', 'SKUNAME', 'VERSION') } | select @{Name = 'Name'; Expression = {$_.PropertyName}}, @{Name = "Value"; Expression = {$_.PropertyStrValue}}
            $sql = New-SQLVersion
            $sql.method = 'WMI'
            $sql.host = $Hostname
            $sql.vmtUuid = $Uuid
            $sql.instanceName = $name

            foreach ($p in $properties)
            {
                switch ($p.Name)
                {
                    "INSTANCEID" { $sql.instanceId = $p.Value; break }
                    "SKUNAME"    { $sql.edition = $p.Value; break }
                    "VERSION"    { $sql.versionNumber = $p.Value; break }
                }
            }

            $sql.version = ConvertTo-SQLDateVersion $sql.versionNumber
            $sql.serviceState = (gwmi -ComputerName $Hostname -Class Win32_Service | ? { $_.Name -eq $s.ServiceName }).State
            $inst += $sql
        }
    }

    $inst
}


# remote powershell (WinRM) session
function Get-SQLByWinRM
{
    param (
        [string] $Hostname,
        [string] $Uuid
    )

    $inst = @()
    $session = New-PSSession -ComputerName $Hostname

    if ($session -and $session.State -eq 'Opened')
    {
        $instanceKey = "HKLM:\\$regSQLRoot\\Instance Names\\SQL"
        $sb = { param([string] $path) Get-Item $path | select -ExpandProperty property }
        $services = Invoke-Command -Session $session -ScriptBlock $sb -ArgumentList $instanceKey

        foreach ($i in $services)
        {
            $sb = { param([string] $path, [string] $name) Get-ItemProperty -Path $path -Name $name }
            $name = (Invoke-Command -Session $session -ScriptBlock $sb -ArgumentList $instanceKey,$i).$i

            $path = "HKLM:\\$regSQLRoot\\" + $name + "\\Setup"
            $sb = { param([string] $path) Get-ItemProperty $path }
            $s = Invoke-Command -Session $session -ScriptBlock $sb -ArgumentList $path

            $sql = New-SQLVersion
            $sql.method = 'WinRM'
            $sql.host = $Hostname
            $sql.vmtUuid = $Uuid
            $sql.instanceName = $i
            $sql.instanceId = $name
            $sql.versionNumber = $s.Version
            $sql.version = ConvertTo-SQLDateVersion $s.Version
            $sql.edition = $s.Edition
            $sql.serviceState = (Get-Service | ? { $_.DisplayName -eq "SQL Server ($($sql.instance))" }).Status

            $inst += $sql
        }

        Remove-PSSession $session
    }

    $inst
}


# Remote registry connection (worst case)
function Get-SQLByReg
{
    param (
        [string] $Hostname,
        [string] $Uuid
    )

    $inst = @()

    if (Test-Connection -ComputerName $Hostname -Count 1 -ea 0)
    {
        $remotereg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Hostname)
        $instanceKey = "$regSQLRoot\\Instance Names\\SQL"

        $_instanceKey = $remotereg.OpenSubKey($instanceKey)
        $instances = $_instanceKey.GetValueNames()

        foreach ($i in $instances)
        {
            $name = $_instanceKey.GetValue($i)
            $setupKey = "$regSQLRoot\\" + $name + "\\Setup"
            $_setupKey = $remotereg.OpenSubKey($setupKey)
            $edition = $_setupKey.GetValue("Edition")
            $version = $_setupKey.GetValue("Version")

            $sql = New-SQLVersion
            $sql.method = 'Registry'
            $sql.host = $Hostname
            $sql.vmtUuid = $Uuid
            $sql.instanceName = $i
            $sql.instanceId = $name
            $sql.versionNumber = $version
            $sql.version = ConvertTo-SQLDateVersion $version
            $sql.edition = $edition
            $sql.serviceState = "Unavailable"
            $inst += $sql
        }
    }

    $inst
}


function Get-SQLVersions
{
    param (
        [string] $Hostname,
        [string] $Uuid
    )

    foreach ($m in $sqlMethods.Keys)
    {
        try
        {
            $versions = @()
            $disabled = Get-Variable Disable$m -ValueOnly

            if (!$disabled)
            {
                $versions = & $sqlMethods[$m] -Hostname $Hostname -Uuid $Uuid

                if ($versions)
                { break }
            }
        }
        catch
        {
            if (($_.Exception.ToString()).Contains("RPC server is unavailable") -or
                ($_.Exception.ToString()).Contains("SQL Server WMI provider is not available")
            )
            {
                Write-Verbose "[$($sqlMethods[$m])] method failed: Service is not installed or disabled"
            }
            elseif (($_.Exception.ToString()).Contains("Access is denied") -or
                ($_.Exception.ToString()).Contains("registry access is not allowed") -or
                ($_.Exception.ToString()).Contains("unauthorized operation")
            )
            {
                Write-Verbose "[$($sqlMethods[$m])] method failed: Access is denied"
            }
            elseif (($_.Exception.ToString()).Contains("network path was not found"))
            {
                Write-Verbose "[$($sqlMethods[$m])] method failed with error: No SQL found"
            }
            else
            {
                Write-Verbose "[$($sqlMethods[$m])] method failed with error:"
                Write-Verbose $_.Exception
            }

            continue
        }
    }

    $versions
}


function Write-SQLVersions
{
    param (
        [string] $Filename,
        [array] $Data
    )

    $Data | select @{Name = "Machine Name"; Expression = {$_.host}},
        @{Name = "Instance Name"; Expression = {$_.instanceName}},
        @{Name = "Instance ID"; Expression = {$_.instanceId}},
        @{Name = "Release Name"; Expression = {$_.version}},
        @{Name = "Version"; Expression = {$_.versionNumber}},
        @{Name = "Edition"; Expression = {$_.edition}},
        @{Name = "Service State"; Expression = {$_.serviceState}} |
        Export-Csv -Path $Filename -NoTypeInformation
}


#
# Main Execution
#
try
{
    Write-Output "Connecting to Turbonomic instance [$ServerName]"
    $vmtCredential = Get-TurbonomicLogin $Credential $Username $Password

    if (!(Invoke-TurboSession))
    {
        Write-Output "Unable to connect to Turbonomic instance"
        exit 0
    }

    Write-Output "Discovering vCenter targets, you will be prompted for credentials for each vCenter..."
    $vms = Get-TurboGroupMembers -Name $SourceGroup
    $vcTargets = Get-VCenterCreds $vms
    $pbActivity = "Checking virtual machines"

    $instances = @()
    $vm_count = $vms.Count
    $vm_prog = -1
    Write-Progress -Id 1 -Activity $pbActivity

    foreach ($key in $vcTargets.Keys)
    {
        try
        {
            Write-Output "Connecting to $key"
            Connect-vcVCenter $key $vcTargets[$key]
        }
        catch
        {
            Write-Output "Error communicating with vCenter target"
            Write-Output $_.Exception
            continue
        }

        foreach ($vm in $vms)
        {
            if ($vm.discoveredBy.displayName -eq $key)
            {
                $machineName, $ip = Get-vcVMHostNameAndIP $vm.displayName $vm.remoteID
                $pbStatus = "$($vm.displayName) [$machineName]"
                $vm_prog += 1
                Write-Output "Checking $($vm.displayName) [$machineName]"
                Write-Verbose "$($vm.displayName) :: $machineName :: $ip"
                Write-Progress -Id 1 -Activity $pbActivity -Status $pbStatus -PercentComplete (($vm_prog / $vm_count) * 100)

                # pre-flight checks
                if ([string]::IsNullOrEmpty($machineName) -or
                    !(Test-Connection $machineName -Count 1 -ea 'SilentlyContinue')
                )
                {
                    if ([string]::IsNullOrEmpty($ip) -or
                        !(Test-Connection $ip -Count 1 -ea 'SilentlyContinue')
                    )
                    { continue }
                    else
                    { $machineName = $ip }
                }

                $vers = Get-SQLVersions $machineName $vm.uuid

                if (!$vers)
                { Write-Verbose "No SQL installed or unable to obtain version infromation from [$machineName]" }
                else
                { $instances += $vers }
            }
        }

        Disconnect-vcVCenter $key
    }

    Write-Progress -Id 1 -Activity $pbActivity -Completed

    if ($instances)
    {
        Write-Output "Recording data to [$OutputFile]..."
        Write-SQLVersions $OutputFile $instances

        Write-Output "Creating Turbonomic groups..."
        Create-TurboGroups $instances $vmtSqlGroups
    }
}
catch
{
    Write-Output $_.Exception
}
finally
{
    $ErrorActionPreference = $oldErrorAction
}