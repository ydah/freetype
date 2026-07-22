# frozen_string_literal: true

begin
  require "harfbuzz"
rescue LoadError => error
  raise LoadError, "freetype/harfbuzz requires the optional harfbuzz-ruby gem (#{error.message})"
end

require_relative "../freetype"
require_relative "text_run"
