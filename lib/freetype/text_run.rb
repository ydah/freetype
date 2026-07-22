# frozen_string_literal: true

module FreeType
  class TextRun
    include Enumerable

    Quad = Data.define(:x0, :y0, :x1, :y1, :u0, :v0, :u1, :v1)

    attr_reader :quads

    def self.layout(shaped, atlas)
      new(layout_quads(shaped, atlas.entries))
    end

    def self.layout_quads(shaped, entries)
      cursor_x = 0.0
      cursor_y = 0.0
      quads = []

      glyph_pairs(shaped).each do |info, position|
        entry = entries[glyph_id(info)]
        if entry && entry.width.positive? && entry.height.positive?
          offset_x = fixed(position, :x_offset)
          offset_y = fixed(position, :y_offset)
          x0 = cursor_x + offset_x + entry.bearing_x
          y0 = cursor_y - offset_y - entry.bearing_y
          quads << Quad.new(
            x0: x0, y0: y0, x1: x0 + entry.width, y1: y0 + entry.height,
            u0: entry.u0, v0: entry.v0, u1: entry.u1, v1: entry.v1
          )
        end
        cursor_x += fixed(position, :x_advance)
        cursor_y -= fixed(position, :y_advance)
      end
      quads.freeze
    end

    def self.glyph_pairs(shaped)
      if shaped.respond_to?(:glyph_infos) && shaped.respond_to?(:glyph_positions)
        return shaped.glyph_infos.zip(shaped.glyph_positions)
      end

      shaped.to_a.map do |pair|
        unless pair.respond_to?(:to_ary) && pair.to_ary.length == 2
          raise ArgumentError, "shaped glyphs must yield [info, position] pairs"
        end

        pair.to_ary
      end
    end

    def self.glyph_id(info)
      return Integer(info.glyph_id) if info.respond_to?(:glyph_id)
      return Integer(info.codepoint) if info.respond_to?(:codepoint)
      return Integer(info.fetch(:glyph_id)) if info.respond_to?(:fetch)

      raise ArgumentError, "glyph info does not expose a glyph_id"
    end

    def self.fixed(position, field)
      value = if position.respond_to?(field)
                position.public_send(field)
              elsif position.respond_to?(:fetch)
                position.fetch(field)
              else
                raise ArgumentError, "glyph position does not expose #{field}"
              end
      FixedPoint.from_26_6(value)
    end

    private_class_method :layout_quads, :glyph_pairs, :glyph_id, :fixed

    def initialize(quads)
      @quads = quads
      freeze
    end

    def each(&block)
      quads.each(&block)
    end

    def [](index)
      quads[index]
    end

    def length
      quads.length
    end

    alias size length

    def empty?
      quads.empty?
    end

    def to_a
      quads.dup
    end

    def to_packed
      if quads.length > 16_384
        raise RangeError, "u16 indices support at most 16384 text quads"
      end

      vertices = quads.flat_map do |quad|
        [
          quad.x0, quad.y0, quad.u0, quad.v0,
          quad.x1, quad.y0, quad.u1, quad.v0,
          quad.x1, quad.y1, quad.u1, quad.v1,
          quad.x0, quad.y1, quad.u0, quad.v1
        ]
      end.pack("e*").freeze
      indices = quads.each_index.flat_map do |index|
        base = index * 4
        [base, base + 1, base + 2, base, base + 2, base + 3]
      end.pack("S<*").freeze
      { vertices: vertices, indices: indices }.freeze
    end
  end
end
