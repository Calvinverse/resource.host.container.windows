# frozen_string_literal: true

#
# Cookbook Name:: resource_container_host_windows
# Recipe:: base
#
# Copyright 2017, P. van der Velde
#

#
# DIRECTORIES
#

logs_directory = node['paths']['log']
directory logs_directory do
  action :create
end

meta_directory = node['paths']['meta']
directory meta_directory do
  action :create
end

ops_directory = node['paths']['ops_base']
directory ops_directory do
  action :create
end
