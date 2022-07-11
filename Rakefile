# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  unless RUBY_VERSION =~ /^2\.7|^3\./
    t.exclude_pattern = 'spec/operation_call_pattern_matching_spec.rb,spec/state_pattern_matching_spec.rb'
  end
end

task :default => :spec
