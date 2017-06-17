# frozen_string_literal: true

#
# Cookbook Name:: resource_container_host_windows
# Recipe:: nomad
#
# Copyright 2017, P. van der Velde
#

service_username = node['service']['nomad_user_name']
service_password = node['service']['nomad_user_password']

# Configure the service user under which nomad will be run
# Make sure that the user password doesn't expire. The password is a random GUID, so it is unlikely that
# it will ever be guessed. And the user is a normal user who can't do anything so we don't really care about it
powershell_script 'nomad_user_with_password_that_does_not_expire' do
  code <<~POWERSHELL
    $user = '#{service_username}'
    $password = '#{service_password}'
    $ObjOU = [ADSI]"WinNT://$env:ComputerName"
    $objUser = $objOU.Create("User", $user)
    $objUser.setpassword($password)
    $objUser.UserFlags = 64 + 65536 # ADS_UF_PASSWD_CANT_CHANGE + ADS_UF_DONT_EXPIRE_PASSWD
    $objUser.SetInfo()
  POWERSHELL
end

# Grant the user the LogOnAsService permission. Following this anwer on SO: http://stackoverflow.com/a/21235462/539846
# With some additional bug fixes to get the correct line from the export file and to put the correct text in the import file
powershell_script 'nomad_user_grant_service_logon_rights' do
  code <<~POWERSHELL
    $ErrorActionPreference = 'Stop'

    $userName = '#{service_username}'

    $tempPath = "c:\\temp"
    if (-not (Test-Path $tempPath))
    {
        New-Item -Path $tempPath -ItemType Directory | Out-Null
    }

    $import = Join-Path -Path $tempPath -ChildPath "import.inf"
    if(Test-Path $import)
    {
        Remove-Item -Path $import -Force
    }

    $export = Join-Path -Path $tempPath -ChildPath "export.inf"
    if(Test-Path $export)
    {
        Remove-Item -Path $export -Force
    }

    $secedt = Join-Path -Path $tempPath -ChildPath "secedt.sdb"
    if(Test-Path $secedt)
    {
        Remove-Item -Path $secedt -Force
    }

    $sid = ((New-Object System.Security.Principal.NTAccount($userName)).Translate([System.Security.Principal.SecurityIdentifier])).Value

    secedit /export /cfg $export
    $line = (Select-String $export -Pattern "SeServiceLogonRight").Line
    $sids = $line.Substring($line.IndexOf('=') + 1).Trim()

    if (-not ($sids.Contains($sid)))
    {
        Write-Host ("Granting SeServiceLogonRight to user account: {0} on host: {1}." -f $userName, $computerName)
        $lines = @(
                "[Unicode]",
                "Unicode=yes",
                "[System Access]",
                "[Event Audit]",
                "[Registry Values]",
                "[Version]",
                "signature=`"`$CHICAGO$`"",
                "Revision=1",
                "[Profile Description]",
                "Description=GrantLogOnAsAService security template",
                "[Privilege Rights]",
                "SeServiceLogonRight = $sids,*$sid"
            )
        foreach ($line in $lines)
        {
            Add-Content $import $line
        }

        secedit /import /db $secedt /cfg $import
        secedit /configure /db $secedt
        gpupdate /force
    }
    else
    {
        Write-Host ("User account: {0} on host: {1} already has SeServiceLogonRight." -f $userName, $computerName)
    }
  POWERSHELL
end

#
# DIRECTORIES
#
nomad_logs_directory = node['paths']['nomad_logs']
directory nomad_logs_directory do
  action :create
  rights :modify, service_username, applies_to_children: true, applies_to_self: false
end

nomad_base_directory = node['paths']['nomad_base']
directory nomad_base_directory do
  action :create
end

nomad_data_directory = node['paths']['nomad_data']
directory nomad_data_directory do
  action :create
  rights :modify, service_username, applies_to_children: true, applies_to_self: false
end

nomad_config_directory = node['paths']['nomad_config']
directory nomad_config_directory do
  action :create
end

nomad_bin_directory = node['paths']['nomad_bin']
directory nomad_bin_directory do
  action :create
  rights :read_execute, 'Everyone', applies_to_children: true, applies_to_self: false
end

#
# INSTALL NOMAD
#

nomad_exe = 'nomad.exe'
cookbook_file "#{nomad_bin_directory}\\#{nomad_exe}" do
  action :create
  source nomad_exe
end

win_service_name = 'nomad_service'
cookbook_file "#{nomad_bin_directory}\\#{win_service_name}.exe" do
  action :create
  source 'WinSW.NET4.exe'
end

#
# CONFIGURATION
#

# We need to multiple-escape the escape character because of ruby string and regex etc. etc. See here: http://stackoverflow.com/a/6209532/539846
nomad_config_file = node['file_name']['nomad_config_file']
nomad_data_directory_json_escaped = nomad_data_directory.gsub('\\', '\\\\\\\\')
file "#{nomad_bin_directory}\\#{nomad_config_file}" do
  action :create
  content <<~HCL
    atlas {
      join = false
    }

    client {
      enabled = true
      node_class = "windows"
      reserved {
        cpu            = 500
        disk           = 1024
        memory         = 512
        reserved_ports = "5989,8300-8600"
      }
    }

    consul {
      address = "127.0.0.1:8500"
      auto_advertise = true
      client_auto_join = true
      server_auto_join = true
    }

    data_dir = "#{nomad_data_directory_json_escaped}"

    disable_update_check = true

    enable_syslog = false

    leave_on_interrupt = true
    leave_on_terminate = true

    log_level = "DEBUG"

    server {
      enabled = false
    }

    vault {
      enabled = false
    }
  HCL
end

file "#{nomad_bin_directory}\\#{win_service_name}.exe.config" do
  action :create
  content <<~XML
    <configuration>
        <runtime>
            <generatePublisherEvidence enabled="false"/>
        </runtime>
    </configuration>
  XML
end

service_name = node['service']['nomad']
file "#{nomad_bin_directory}\\#{win_service_name}.xml" do
  action :create
  content <<~XML
    <?xml version="1.0"?>
    <!--
        The MIT License Copyright (c) 2004-2009, Sun Microsystems, Inc., Kohsuke Kawaguchi Permission is hereby granted, free of charge, to any person obtaining a
        copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
        subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
        PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
        OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    -->

    <service>
        <id>#{service_name}</id>
        <name>#{service_name}</name>
        <description>This service runs the nomad agent.</description>

        <executable>#{nomad_bin_directory}\\nomad.exe</executable>
        <arguments>agent -config=#{nomad_bin_directory}\\#{nomad_config_file} -config=#{nomad_config_directory}</arguments>

        <logpath>#{nomad_logs_directory}</logpath>
        <log mode="roll-by-size">
            <sizeThreshold>10240</sizeThreshold>
            <keepFiles>8</keepFiles>
        </log>
        <onfailure action="restart"/>
    </service>
  XML
end

#
# WINDOWS SERVICE
#

# Create the event log source for the nomad service. We'll create it now because the service runs as a normal user
# and is as such not allowed to create eventlog sources
registry_key "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\services\\eventlog\\Application\\#{service_name}" do
  action :create
  values [{
    data: 'c:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\EventLogMessages.dll',
    name: 'EventMessageFile',
    type: :string
  }]
end

powershell_script 'nomad_as_service' do
  code <<~POWERSHELL
    $ErrorActionPreference = 'Stop'

    $securePassword = ConvertTo-SecureString "#{service_password}" -AsPlainText -Force

    # Note the .\\ is to get the local machine account as per here:
    # http://stackoverflow.com/questions/313622/powershell-script-to-change-service-account#comment14535084_315616
    $credential = New-Object pscredential((".\\" + "#{service_username}"), $securePassword)

    $service = Get-Service -Name '#{service_name}' -ErrorAction SilentlyContinue
    if ($service -eq $null)
    {
        New-Service `
            -Name '#{service_name}' `
            -BinaryPathName '#{nomad_bin_directory}\\#{win_service_name}.exe' `
            -Credential $credential `
            -DisplayName '#{service_name}' `
            -StartupType Disabled
    }

    # Set the service to restart if it fails
    sc.exe failure #{service_name} reset=86400 actions=restart/5000
  POWERSHELL
end

#
# ALLOW NOMAD THROUGH THE FIREWALL
#

firewall_rule 'nomad-http' do
  command :allow
  description 'Allow Nomad HTTP traffic'
  dest_port 4646
  direction :in
end

firewall_rule 'nomad-rpc' do
  command :allow
  description 'Allow Nomad RCP traffic'
  dest_port 4647
  direction :in
end

firewall_rule 'nomad-serf' do
  command :allow
  description 'Allow Nomad Serf traffic'
  dest_port 4648
  direction :in
end
