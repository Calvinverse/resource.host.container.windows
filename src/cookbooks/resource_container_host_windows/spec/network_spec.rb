# frozen_string_literal: true

require 'spec_helper'

describe 'resource_container_host_windows::network' do
  acrylic_logs_directory = 'c:\\logs\\acrylic'
  acrylic_base_path = 'c:\\ops\\acrylic'

  context 'create the log locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the acrylic logs directory' do
      expect(chef_run).to create_directory(acrylic_logs_directory)
    end
  end

  context 'create the acrylic locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the acrylic base directory' do
      expect(chef_run).to create_directory(acrylic_base_path)
    end

    it 'creates AcrylicController.exe in the acrylic ops directory' do
      expect(chef_run).to create_cookbook_file("#{acrylic_base_path}\\AcrylicController.exe").with_source('acrylic/AcrylicController.exe')
    end

    it 'creates AcrylicController.exe.manifest in the acrylic ops directory' do
      expect(chef_run).to create_cookbook_file("#{acrylic_base_path}\\AcrylicController.exe.manifest").with_source('acrylic/AcrylicController.exe.manifest')
    end

    it 'creates AcrylicService.exe in the acrylic ops directory' do
      expect(chef_run).to create_cookbook_file("#{acrylic_base_path}\\AcrylicService.exe").with_source('acrylic/AcrylicService.exe')
    end
  end

  context 'install acrylic as service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs acrylic as service' do
      expect(chef_run).to run_powershell_script('acrylic_as_service')
    end

    acrylic_default_config_content = <<~INI
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
    it 'creates acrylicconfiguration.ini in the acrylic ops directory' do
      expect(chef_run).to create_file("#{acrylic_base_path}\\AcrylicConfiguration.ini").with_content(acrylic_default_config_content)
    end
  end

  context 'configures windows dns' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    # Note the data values are the SHA hash of the value '0'. For some reason Chef processes the
    # values before it gets to the test which means chef stores the SHA hash, not the actual number.
    it 'disables the DNS caching of negative responses' do
      expect(chef_run).to create_registry_key('HKLM\\SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters').with(
        values: [
          {
            name: 'NegativeCacheTime',
            type: :dword,
            data: '5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9'
          },
          {
            name: 'NetFailureCacheTime',
            type: :dword,
            data: '5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9'
          },
          {
            name: 'NegativeSOACacheTime',
            type: :dword,
            data: '5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9'
          },
          {
            name: 'MaxNegativeCacheTtl',
            type: :dword,
            data: '5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9'
          }
        ]
      )
    end
  end

  context 'configures the firewall for consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Acrylic DNS UDP port' do
      expect(chef_run).to create_firewall_rule('acrylic-dns-udp').with(
        command: :allow,
        dest_port: 53,
        direction: :in,
        protocol: :udp
      )
    end

    it 'opens the Acrylic DNS TCP port' do
      expect(chef_run).to create_firewall_rule('acrylic-dns-tcp').with(
        command: :allow,
        dest_port: 53,
        direction: :in,
        protocol: :tcp
      )
    end
  end
end
