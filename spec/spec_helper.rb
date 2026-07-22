# frozen_string_literal: true

require "freetype"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!
  config.filter_run_excluding gpu: true unless ENV["FREETYPE_GPU_TEST"] == "1"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
