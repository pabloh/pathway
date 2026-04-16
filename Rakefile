# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

RSpec::Core::RakeTask.new(:spec_without_active_support) do |t|
  t.exclude_pattern = "spec/plugins/active_record_spec.rb"
end
