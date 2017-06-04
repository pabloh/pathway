require 'bundler/setup'

if ENV['CI']
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.start do
    add_filter '/spec/'
  end
end

require 'pathway'
require 'sequel'

# Load testing support files
Dir[__dir__ + '/support/**/*.rb'].each { |support| require support }

RSpec::Matchers.define_negated_matcher :exclude, :include

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'

  config.color = true
  config.tty = true
  config.formatter = :documentation
  config.profile_examples = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
    c.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |c|
    c.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus

  config.order = :random
  Kernel.srand config.seed
end
