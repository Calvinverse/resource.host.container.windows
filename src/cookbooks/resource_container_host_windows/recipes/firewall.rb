# frozen_string_literal: true

#
# Cookbook Name:: resource_container_host_windows
# Recipe:: firewall
#
# Copyright 2017, P. van der Velde
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
node.default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
node.default['firewall']['allow_mosh'] = false

# do not allow SSH
node.default['firewall']['allow_ssh'] = false

# No communication via IPv6 at all
node.default['firewall']['ipv6_enabled'] = false

firewall 'default' do
  action :install
end

firewall_rule 'winrm' do
  command :allow
  description 'Allow WinRM traffic'
  dest_port 5989
  direction :in
end
