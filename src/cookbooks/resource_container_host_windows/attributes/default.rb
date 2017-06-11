# frozen_string_literal: true

logs_path = 'c:\\logs'
default['paths']['log'] = logs_path

meta_base_path = 'c:\\meta'
default['paths']['meta'] = meta_base_path

ops_base_path = 'c:\\ops'
default['paths']['ops_base'] = ops_base_path

# Consul
default['service']['consul_user_name'] = 'consul_user'
default['service']['consul_user_password'] = SecureRandom.uuid

default['service']['consul'] = 'consul'

consul_base_path = "#{ops_base_path}\\consul"
default['paths']['consul_base'] = consul_base_path
default['paths']['consul_bin'] = "#{consul_base_path}\\bin"
default['paths']['consul_data'] = "#{consul_base_path}\\data"

default['paths']['consul_logs'] = "#{logs_path}\\consul"

consul_config_path = "#{meta_base_path}\\consul"
default['paths']['consul_config'] = consul_config_path
default['paths']['consul_checks'] = "#{consul_config_path}\\checks"

default['file_name']['consul_config_file'] = 'consul_default.json'

# Docker
default['service']['docker'] = 'docker'

docker_base_path = "#{ops_base_path}\\docker"
default['paths']['docker_base'] = docker_base_path

# Nomad
default['service']['nomad_user_name'] = 'nomad_user'
default['service']['nomad_user_password'] = SecureRandom.uuid

default['service']['nomad'] = 'nomad'

nomad_base_path = "#{ops_base_path}\\nomad"
default['paths']['nomad_base'] = nomad_base_path
default['paths']['nomad_bin'] = "#{nomad_base_path}\\bin"
default['paths']['nomad_data'] = "#{nomad_base_path}\\data"

default['paths']['nomad_logs'] = "#{logs_path}\\nomad"

nomad_config_path = "#{meta_base_path}\\nomad"
default['paths']['nomad_config'] = nomad_config_path

default['file_name']['nomad_config_file'] = 'nomad_default.hcl'

# Provisioning
default['service']['provisioning'] = 'provisioning'

provisioning_base_path = "#{ops_base_path}\\provisioning"
default['paths']['provisioning_base'] = provisioning_base_path
default['paths']['provisioning_service'] = "#{provisioning_base_path}\\service"

provisioning_logs_path = "#{logs_path}\\provisioning"
default['paths']['provisioning_logs'] = provisioning_logs_path
