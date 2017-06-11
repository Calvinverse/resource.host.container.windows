# frozen_string_literal: true

#
# Cookbook Name:: resource_container_host_windows
# Recipe:: default
#
# Copyright 2017, P. van der Velde
#

include_recipe 'resource_container_host_windows::firewall'
include_recipe 'resource_container_host_windows::consul'
include_recipe 'resource_container_host_windows::docker'
include_recipe 'resource_container_host_windows::nomad'
include_recipe 'resource_container_host_windows::provisioning'
