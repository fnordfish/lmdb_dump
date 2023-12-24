# frozen_string_literal: true

if ["1", "true"].include?(ENV["COVERAGE"])
  require "simplecov"

  SimpleCov.formatter = case ENV["SIMPLECOV"]&.downcase
  when "json"
    require "simplecov_json_formatter"
    SimpleCov::Formatter::JSONFormatter
  else
    SimpleCov::Formatter::HTMLFormatter
  end

  SimpleCov.start do
    add_filter %r{^/spec/}
  end
end

require "lmdb_dump"
require_relative "support/lmdb_helpers"

RSpec.configure do |config|
  config.include LMDBHelpers

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
    c.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.order = :random
  Kernel.srand config.seed

  config.before(:suite) do
    LMDBHelpers.create_fixtures!
  end

  config.after do
    @lmdb_env&.close
    FileUtils.rm_rf(LMDBHelpers::TMP_PATH)
  end
end
