# frozen_string_literal: true

require 'spec_helper'

describe 'resource_container_host_windows::nomad' do
  nomad_logs_directory = 'c:\\logs\\nomad'

  nomad_config_directory = 'c:\\meta\\nomad'

  nomad_base_path = 'c:\\ops\\nomad'
  nomad_data_directory = 'c:\\ops\\nomad\\data'
  nomad_bin_directory = 'c:\\ops\\nomad\\bin'

  service_name = 'nomad'
  nomad_config_file = 'nomad_default.hcl'

  context 'create the log locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the nomad logs directory' do
      expect(chef_run).to create_directory(nomad_logs_directory)
    end
  end

  context 'create the config locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the nomad config directory' do
      expect(chef_run).to create_directory(nomad_config_directory)
    end
  end

  context 'create the nomad locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the nomad base directory' do
      expect(chef_run).to create_directory(nomad_base_path)
    end

    it 'creates the nomad data directory' do
      expect(chef_run).to create_directory(nomad_data_directory)
    end

    it 'creates the nomad bin directory' do
      expect(chef_run).to create_directory(nomad_bin_directory)
    end

    it 'creates nomad.exe in the nomad ops directory' do
      expect(chef_run).to create_cookbook_file("#{nomad_bin_directory}\\#{service_name}.exe").with_source("#{service_name}.exe")
    end
  end

  context 'create the user to run the service with' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the nomad user' do
      expect(chef_run).to run_powershell_script('nomad_user_with_password_that_does_not_expire')
    end
  end

  context 'install nomad as service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    win_service_name = 'nomad_service'
    it 'creates nomad_service.exe in the nomad ops directory' do
      expect(chef_run).to create_cookbook_file("#{nomad_bin_directory}\\#{win_service_name}.exe").with_source('WinSW.NET4.exe')
    end

    nomad_service_exe_config_content = <<~XML
      <configuration>
          <runtime>
              <generatePublisherEvidence enabled="false"/>
          </runtime>
      </configuration>
    XML
    it 'creates nomad_service.exe.config in the nomad ops directory' do
      expect(chef_run).to create_file("#{nomad_bin_directory}\\#{win_service_name}.exe.config").with_content(nomad_service_exe_config_content)
    end

    nomad_service_xml_content = <<~XML
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
    it 'creates nomad_service.xml in the nomad ops directory' do
      expect(chef_run).to create_file("#{nomad_bin_directory}\\#{win_service_name}.xml").with_content(nomad_service_xml_content)
    end

    it 'installs nomad as service' do
      expect(chef_run).to run_powershell_script('nomad_as_service')
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

    nomad_client_config_content = <<~HCL
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

      data_dir = "c:\\\\ops\\\\nomad\\\\data"

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
    it 'creates nomad_client.hcl in the nomad configuration directory' do
      expect(chef_run).to create_file("#{nomad_bin_directory}\\nomad_default.hcl")
        .with_content(nomad_client_config_content)
    end
  end

  context 'configures the firewall for nomad' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Nomad HTTP port' do
      expect(chef_run).to create_firewall_rule('nomad-http').with(
        command: :allow,
        dest_port: 4646,
        direction: :in
      )
    end

    it 'opens the Nomad serf LAN port' do
      expect(chef_run).to create_firewall_rule('nomad-rpc').with(
        command: :allow,
        dest_port: 4647,
        direction: :in
      )
    end

    it 'opens the Nomad serf WAN port' do
      expect(chef_run).to create_firewall_rule('nomad-serf').with(
        command: :allow,
        dest_port: 4648,
        direction: :in
      )
    end
  end
end
