# frozen_string_literal: true

#
# Cookbook Name:: resource_container_host_windows
# Recipe:: network
#
# Copyright 2017, P. van der Velde
#

#
# CONFIGURE ACRYLIC
#

acrylic_logs_directory = node['paths']['acrylic_logs']
directory acrylic_logs_directory do
  action :create
  rights :modify, 'LocalService', applies_to_children: true, applies_to_self: false
end

acrylic_base_directory = node['paths']['acrylic_base']
directory acrylic_base_directory do
  action :create
end

cookbook_file "#{acrylic_base_directory}\\AcrylicController.exe" do
  action :create
  source 'acrylic/AcrylicController.exe'
end

cookbook_file "#{acrylic_base_directory}\\AcrylicController.exe.manifest" do
  action :create
  source 'acrylic/AcrylicController.exe.manifest'
end

cookbook_file "#{acrylic_base_directory}\\AcrylicService.exe" do
  action :create
  source 'acrylic/AcrylicService.exe'
end

# We need to multiple-escape the escape character because of ruby string and regex etc. etc. See here: http://stackoverflow.com/a/6209532/539846
acrylic_config_file = node['file_name']['acrylic_config_file']
file "#{acrylic_base_directory}\\#{acrylic_config_file}" do
  action :create
  content <<~INI
    [GlobalSection]
    PrimaryServerAddress=127.0.0.1
    PrimaryServerPort=8600
    PrimaryServerProtocol=UDP
    PrimaryServerDomainNameAffinityMask=*.${CONSUL_DOMAIN}
    IgnoreNegativeResponsesFromPrimaryServer=No

    SecondaryServerAddress=${SECOND_DNS_IP}
    SecondaryServerPort=53
    SecondaryServerProtocol=UDP
    SecondaryServerDomainNameAffinityMask=^*.${CONSUL_DOMAIN};*
    IgnoreNegativeResponsesFromSecondaryServer=No

    TertiaryServerAddress=${THIRD_DNS_IP}
    TertiaryServerPort=53
    TertiaryServerProtocol=UDP
    TertiaryServerDomainNameAffinityMask=^*.${CONSUL_DOMAIN};*
    IgnoreNegativeResponsesFromTertiaryServer=No

    AddressCacheDisabled=Yes

    LocalIPv4BindingAddress=0.0.0.0
    LocalIPv4BindingPort=53
    LocalIPv6BindingAddress=0:0:0:0:0:0:0:0
    LocalIPv6BindingPort=53

    GeneratedResponseTimeToLive=60

    HitLogFileName=#{acrylic_logs_directory}\\HitLog.%DATE%.log
    HitLogFileWhat=BHCFRU
    StatsLogFileName=#{acrylic_logs_directory}\\statlog.log

    [AllowedAddressesSection]
    [CacheExceptionsSection]
    [WhiteExceptionsSection]
  INI
end

powershell_script 'acrylic_as_service' do
  code <<~POWERSHELL
    $ErrorActionPreference = 'Stop'

    & #{acrylic_base_directory}\\AcrylicController.exe InstallAcrylicService

    # Set the service to restart if it fails
    # sc.exe failure AcrylicServiceController reset=86400 actions=restart/5000
  POWERSHELL
end

firewall_rule 'acrylic-dns-udp' do
  command :allow
  description 'Allow Acrylic DNS (UDP) proxy traffic'
  dest_port 53
  direction :in
  protocol :udp
end

firewall_rule 'acrylic-dns-tcp' do
  command :allow
  description 'Allow Acrylic DNS (TCP) proxy traffic'
  dest_port 53
  direction :in
  protocol :tcp
end

#
# WINDOWS DNS SETTINGS
#

# Disable the caching of negative DNS responses because that would stop acrylic from working as a DNS for a period of time
# if there is a failed DNS request (e.g. the acrylic machine is busy or something)
registry_key 'HKLM\\SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters' do
  values [
    {
      name: 'NegativeCacheTime',
      type: :dword,
      data: 0x0
    },
    {
      name: 'NetFailureCacheTime',
      type: :dword,
      data: 0x0
    },
    {
      name: 'NegativeSOACacheTime',
      type: :dword,
      data: 0x0
    },
    {
      name: 'MaxNegativeCacheTtl',
      type: :dword,
      data: 0x0
    }
  ]
  action :create
end
