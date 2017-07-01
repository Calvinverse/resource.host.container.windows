# frozen_string_literal: true

require 'spec_helper'

describe 'resource_container_host_windows::provisioning' do
  provisioning_logs_directory = 'c:\\logs\\provisioning'

  provisioning_base_path = 'c:\\ops\\provisioning'
  provisioning_service_directory = 'c:\\ops\\provisioning\\service'

  service_name = 'provisioning'
  provisioning_script = 'Initialize-Resource.ps1'

  context 'create the log locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the provisioning logs directory' do
      expect(chef_run).to create_directory(provisioning_logs_directory)
    end
  end

  context 'create the provisioning locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the provisioning base directory' do
      expect(chef_run).to create_directory(provisioning_base_path)
    end

    it 'creates the provisioning service directory' do
      expect(chef_run).to create_directory(provisioning_service_directory)
    end

    it 'creates provisioning.exe in the provisioning ops directory' do
      expect(chef_run).to create_cookbook_file("#{provisioning_base_path}\\#{provisioning_script}").with_source(provisioning_script)
    end
  end

  context 'install provisioning as service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    win_service_name = 'provisioning_service'
    it 'creates provisioning_service.exe in the provisioning ops directory' do
      expect(chef_run).to create_cookbook_file("#{provisioning_service_directory}\\#{win_service_name}.exe").with_source('WinSW.NET4.exe')
    end

    provisioning_service_exe_config_content = <<~XML
      <configuration>
          <runtime>
              <generatePublisherEvidence enabled="false"/>
          </runtime>
      </configuration>
    XML
    it 'creates provisioning_service.exe.config in the provisioning ops directory' do
      expect(chef_run).to create_file("#{provisioning_service_directory}\\#{win_service_name}.exe.config").with_content(provisioning_service_exe_config_content)
    end

    provisioning_service_xml_content = <<~XML
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
          <description>This service executes the environment provisioning for the current resource.</description>

          <executable>powershell.exe</executable>
          <arguments>-NonInteractive -NoProfile -NoLogo -ExecutionPolicy RemoteSigned -File #{provisioning_base_path}\\#{provisioning_script}</arguments>

          <logpath>#{provisioning_logs_directory}</logpath>
          <log mode="roll-by-size">
              <sizeThreshold>10240</sizeThreshold>
              <keepFiles>8</keepFiles>
          </log>
          <onfailure action="none"/>
      </service>
    XML
    it 'creates provisioning_service.xml in the provisioning ops directory' do
      expect(chef_run).to create_file("#{provisioning_service_directory}\\#{win_service_name}.xml").with_content(provisioning_service_xml_content)
    end

    it 'installs provisioning as service' do
      expect(chef_run).to run_powershell_script('provisioning_as_service')
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
  end
end
