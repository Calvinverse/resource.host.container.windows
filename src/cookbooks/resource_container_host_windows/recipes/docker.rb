# frozen_string_literal: true

#
# Cookbook Name:: resource_container_host_windows
# Recipe:: docker
#
# Copyright 2017, P. van der Velde
#

windows_feature 'containers' do
  action :install
end

docker_base_directory = node['paths']['docker_base']
directory docker_base_directory do
  action :create
end

cookbook_file "#{docker_base_directory}\\docker.exe" do
  source 'docker\\docker.exe'
  action :create
end

cookbook_file "#{docker_base_directory}\\dockerd.exe" do
  source 'docker\\dockerd.exe'
  action :create
end

windows_path docker_base_directory do
  action :add
end

powershell_script 'docker_as_service' do
  code <<~POWERSHELL
    $ErrorActionPreference = 'Stop'

    & #{docker_base_directory}\\dockerd.exe --register-service
  POWERSHELL
end

# The docker network is set in the provisioning step because we need to set the IP range to something
# sensible
