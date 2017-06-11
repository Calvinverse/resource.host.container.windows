# frozen_string_literal: true

require 'spec_helper'

describe 'resource_container_host_windows::consul' do
  consul_logs_directory = 'c:\\logs\\consul'

  consul_config_directory = 'c:\\meta\\consul'
  consul_checks_directory = 'c:\\meta\\consul\\checks'

  consul_base_path = 'c:\\ops\\consul'
  consul_data_directory = 'c:\\ops\\consul\\data'
  consul_bin_directory = 'c:\\ops\\consul\\bin'

  service_name = 'consul'
  consul_config_file = 'consul_default.json'

  context 'create the log locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consul logs directory' do
      expect(chef_run).to create_directory(consul_logs_directory)
    end
  end

  context 'create the config locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consul config directory' do
      expect(chef_run).to create_directory(consul_config_directory)
    end

    it 'creates the consul checks directory' do
      expect(chef_run).to create_directory(consul_checks_directory)
    end
  end

  context 'create the consul locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consul base directory' do
      expect(chef_run).to create_directory(consul_base_path)
    end

    it 'creates the consul data directory' do
      expect(chef_run).to create_directory(consul_data_directory)
    end

    it 'creates the consul bin directory' do
      expect(chef_run).to create_directory(consul_bin_directory)
    end

    it 'creates consul.exe in the consul ops directory' do
      expect(chef_run).to create_cookbook_file("#{consul_bin_directory}\\#{service_name}.exe").with_source("#{service_name}.exe")
    end
  end

  context 'create the user to run the service with' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consul user' do
      expect(chef_run).to run_powershell_script('consul_user_with_password_that_does_not_expire')
    end
  end

  context 'install consul as service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    win_service_name = 'consul_service'
    it 'creates consul_service.exe in the consul ops directory' do
      expect(chef_run).to create_cookbook_file("#{consul_bin_directory}\\#{win_service_name}.exe").with_source('WinSW.NET4.exe')
    end

    consul_service_exe_config_content = <<~XML
      <configuration>
          <runtime>
              <generatePublisherEvidence enabled="false"/>
          </runtime>
      </configuration>
    XML
    it 'creates consul_service.exe.config in the consul ops directory' do
      expect(chef_run).to create_file("#{consul_bin_directory}\\#{win_service_name}.exe.config").with_content(consul_service_exe_config_content)
    end

    consul_service_xml_content = <<~XML
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
          <description>This service runs the consul agent.</description>

          <executable>#{consul_bin_directory}\\consul.exe</executable>
          <arguments>agent -config-file=#{consul_bin_directory}\\#{consul_config_file} -config-dir=#{consul_config_directory}</arguments>

          <logpath>#{consul_logs_directory}</logpath>
          <log mode="roll-by-size">
              <sizeThreshold>10240</sizeThreshold>
              <keepFiles>8</keepFiles>
          </log>
          <onfailure action="restart"/>
      </service>
    XML
    it 'creates consul_service.xml in the consul ops directory' do
      expect(chef_run).to create_file("#{consul_bin_directory}\\#{win_service_name}.xml").with_content(consul_service_xml_content)
    end

    it 'installs consul as service' do
      expect(chef_run).to run_powershell_script('consul_as_service')
    end

    it 'creates the windows service event log' do
      expect(chef_run).to create_registry_key("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\services\\eventlog\\Application\\#{service_name}").with(
        values: [{
          name: 'EventMessageFile',
          type: :string,
          data: 'c:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\EventLogMessages.dll'
        }]
      )
    end

    consul_default_config_content = <<~JSON
      {
        "data_dir": "c:\\\\ops\\\\consul\\\\data",

        "domain": "consulverse",

        "disable_remote_exec": true,
        "disable_update_check": true,

        "log_level" : "debug",

        "server": false
      }
    JSON
    it 'creates consul_default.json in the consul ops directory' do
      expect(chef_run).to create_file("#{consul_bin_directory}\\#{consul_config_file}").with_content(consul_default_config_content)
    end
  end

  context 'configures the firewall for consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Consul HTTP port' do
      expect(chef_run).to create_firewall_rule('consul-http').with(
        command: :allow,
        dest_port: 8500,
        direction: :in
      )
    end

    it 'opens the Consul rpc port' do
      expect(chef_run).to create_firewall_rule('consul-rpc').with(
        command: :allow,
        dest_port: 8300,
        direction: :in
      )
    end

    it 'opens the Consul serf LAN TCP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-lan-tcp').with(
        command: :allow,
        dest_port: 8301,
        direction: :in,
        protocol: :tcp
      )
    end

    it 'opens the Consul serf LAN UDP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-lan-udp').with(
        command: :allow,
        dest_port: 8301,
        direction: :in,
        protocol: :udp
      )
    end

    it 'opens the Consul serf WAN TCP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-wan-tcp').with(
        command: :allow,
        dest_port: 8302,
        direction: :in,
        protocol: :tcp
      )
    end

    it 'opens the Consul serf WAN UDP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-wan-udp').with(
        command: :allow,
        dest_port: 8302,
        direction: :in,
        protocol: :udp
      )
    end
  end
end
