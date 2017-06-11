# frozen_string_literal: true

require 'spec_helper'

describe 'resource_container_host_windows::docker' do
  docker_base_path = 'c:\\ops\\docker'
  service_name = 'docker'
  service_daemon_name = 'dockerd'

  context 'create the docker locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the docker base directory' do
      expect(chef_run).to create_directory(docker_base_path)
    end

    it 'creates docker.exe in the docker ops directory' do
      expect(chef_run).to create_cookbook_file("#{docker_base_path}\\#{service_name}.exe").with_source("docker\\#{service_name}.exe")
    end

    it 'creates dockerd.exe in the docker ops directory' do
      expect(chef_run).to create_cookbook_file("#{docker_base_path}\\#{service_daemon_name}.exe").with_source("docker\\#{service_daemon_name}.exe")
    end
  end

  context 'install docker as service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs docker as service' do
      expect(chef_run).to run_powershell_script('docker_as_service')
    end
  end
end
