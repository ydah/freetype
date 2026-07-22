# frozen_string_literal: true

module FreeType
  class Glyph
    attr_reader :id, :bitmap, :bearing_x, :bearing_y, :advance, :width, :height, :raw

    def initialize(id:, slot:)
      native_bitmap = slot[:bitmap]
      @id = id
      @width = native_bitmap[:width]
      @height = native_bitmap[:rows]
      @bearing_x = slot[:bitmap_left].to_f
      @bearing_y = slot[:bitmap_top].to_f
      @advance = FixedPoint.from_26_6(slot[:advance][:x])
      @raw = slot
      @bitmap = Image.build(width: width, height: height, data: BitmapConverter.copy(native_bitmap))
      freeze
    end
  end
end
