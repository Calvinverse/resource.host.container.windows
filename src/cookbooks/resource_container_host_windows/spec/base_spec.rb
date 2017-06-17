# frozen_string_literal: true

require 'spec_helper'

describe 'resource_container_host_windows::base' do
  logs_directory = 'c:\\logs'
  meta_directory = 'c:\\meta'
  ops_directory = 'c:\\ops'

  context 'create the base locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the logs directory' do
      expect(chef_run).to create_directory(logs_directory)
    end

    it 'creates the meta directory' do
      expect(chef_run).to create_directory(meta_directory)
    end

    it 'creates the ops directory' do
      expect(chef_run).to create_directory(ops_directory)
    end
  end
end
