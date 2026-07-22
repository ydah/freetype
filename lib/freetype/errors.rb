# frozen_string_literal: true

module FreeType
  class Error < StandardError; end
  class ClosedError < Error; end
  class StateError < Error; end
  class UnsupportedError < Error; end
  class AtlasError < Error; end

  class NativeError < Error
    attr_reader :code, :name

    def initialize(code, operation: nil)
      @code = Integer(code)
      @name = Native::ERROR_NAMES.fetch(@code, :Unknown_Error)
      prefix = operation ? "#{operation} failed: " : ""
      super(format("%sFreeType error 0x%02X (%s)", prefix, @code, @name))
    end
  end
end
