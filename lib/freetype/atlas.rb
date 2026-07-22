# frozen_string_literal: true

module FreeType
  class Atlas
    Entry = Data.define(
      :u0, :v0, :u1, :v1, :bearing_x, :bearing_y, :width, :height, :advance
    )
    Placement = Data.define(:glyph, :x, :y)

    attr_reader :image, :entries, :metrics, :missing

    def self.build(face, chars: nil, glyph_ids: nil, size:, mode: :gray, padding: 2, max_width: 1024, spread: 8)
      new(face, chars: chars, glyph_ids: glyph_ids, size: size, mode: mode,
        padding: padding, max_width: max_width, spread: spread)
    end

    def initialize(face, chars:, glyph_ids:, size:, mode:, padding:, max_width:, spread:)
      validate_options!(chars, glyph_ids, size, padding, max_width)
      face.set_pixel_size(size)
      glyphs, @missing = rasterize(face, chars, glyph_ids, mode, spread)
      placements, width, height = pack(glyphs, padding, max_width)
      pixels = compose(placements, width, height, padding)
      @image = Image.build(width: width, height: height, data: pixels)
      @entries = build_entries(placements, width, height, padding).freeze
      @metrics = face.metrics
      @missing = @missing.freeze
      freeze
    end

    private

    def validate_options!(chars, glyph_ids, size, padding, max_width)
      if chars.nil? == glyph_ids.nil?
        raise ArgumentError, "provide exactly one of chars or glyph_ids"
      end
      raise ArgumentError, "size must be a positive integer" unless size.is_a?(Integer) && size.positive?
      raise ArgumentError, "padding must be a non-negative integer" unless padding.is_a?(Integer) && padding >= 0
      unless max_width.is_a?(Integer) && max_width.positive?
        raise ArgumentError, "max_width must be a positive integer"
      end
    end

    def rasterize(face, chars, glyph_ids, mode, spread)
      ids = if glyph_ids
              glyph_ids.to_a.map { |id| Integer(id) }
            else
              characters(chars).map { |character| face.char_index(character) }
            end

      missing = []
      glyphs = ids.uniq.filter_map do |id|
        face.glyph_by_id(id, mode: mode, spread: spread)
      rescue NativeError, RangeError
        missing << id
        nil
      end
      [glyphs, missing]
    end

    def characters(chars)
      chars.is_a?(String) ? chars.each_char.to_a : chars.to_a
    end

    def pack(glyphs, padding, max_width)
      shelf_width = 1 << (max_width.bit_length - 1)
      x = 0
      y = 0
      shelf_height = 0
      used_width = 0
      placements = []

      glyphs.sort_by { |glyph| [-glyph.height, -glyph.width, glyph.id] }.each do |glyph|
        packed_width = glyph.width + (padding * 2)
        packed_height = glyph.height + (padding * 2)
        if packed_width > shelf_width
          raise AtlasError, "glyph #{glyph.id} is wider than max_width #{max_width} after power-of-two rounding"
        end

        if x.positive? && x + packed_width > shelf_width
          y += shelf_height
          x = 0
          shelf_height = 0
        end

        placements << Placement.new(glyph: glyph, x: x, y: y)
        x += packed_width
        shelf_height = [shelf_height, packed_height].max
        used_width = [used_width, x].max
      end

      used_height = y + shelf_height
      [placements.freeze, power_of_two([used_width, 1].max), power_of_two([used_height, 1].max)]
    end

    def compose(placements, width, height, padding)
      pixels = "\0".b * (width * height)
      placements.each do |placement|
        glyph = placement.glyph
        source = Image.data(glyph.bitmap)
        glyph.height.times do |row|
          destination_offset = ((placement.y + padding + row) * width) + placement.x + padding
          pixels[destination_offset, glyph.width] = source.byteslice(row * glyph.width, glyph.width)
        end
      end
      pixels.freeze
    end

    def build_entries(placements, width, height, padding)
      placements.to_h do |placement|
        glyph = placement.glyph
        x = placement.x + padding
        y = placement.y + padding
        entry = Entry.new(
          u0: x.fdiv(width), v0: y.fdiv(height),
          u1: (x + glyph.width).fdiv(width), v1: (y + glyph.height).fdiv(height),
          bearing_x: glyph.bearing_x, bearing_y: glyph.bearing_y,
          width: glyph.width, height: glyph.height, advance: glyph.advance
        )
        [glyph.id, entry]
      end
    end

    def power_of_two(value)
      1 << (value - 1).bit_length
    end
  end
end
