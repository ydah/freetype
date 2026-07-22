# frozen_string_literal: true

module FreeType
  Metrics = Data.define(:ascender, :descender, :line_height, :max_advance)

  module FixedPoint
    module_function

    def from_26_6(value)
      Integer(value) / 64.0
    end

    def from_16_16(value)
      Integer(value) / 65_536.0
    end
  end
end
