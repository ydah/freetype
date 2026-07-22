# frozen_string_literal: true

module FreeType
  module FaceRasterization
    def char_index(character)
      ensure_open!
      Native.FT_Get_Char_Index(pointer, codepoint_for(character))
    end

    def glyph(character, mode: :gray, spread: 8, load_flags: Native::FT_LOAD_DEFAULT)
      glyph_by_id(char_index(character), mode: mode, spread: spread, load_flags: load_flags)
    end

    def glyph_by_id(glyph_id, mode: :gray, spread: 8, load_flags: Native::FT_LOAD_DEFAULT)
      ensure_open!
      id = Integer(glyph_id)
      raise RangeError, "glyph id #{id} is outside this face" unless id.between?(0, glyph_count - 1)

      render_mode = self.class::RENDER_MODES.fetch(mode) do
        raise ArgumentError, "unknown render mode #{mode.inspect}"
      end
      prepare_sdf!(spread) if mode == :sdf
      flags = Integer(load_flags) & ~Native::FT_LOAD_RENDER
      flags |= Native::FT_LOAD_TARGET_MONO if mode == :mono
      Native.check!(Native.FT_Load_Glyph(pointer, id, flags), "FT_Load_Glyph")
      slot_pointer = raw[:glyph]
      Native.check!(Native.FT_Render_Glyph(slot_pointer, render_mode), "FT_Render_Glyph")
      Glyph.new(id: id, slot: Native::GlyphSlotRec.new(slot_pointer))
    end

    def kerning(left_glyph_id, right_glyph_id)
      ensure_open!
      vector = Native::Vector.new
      Native.check!(
        Native.FT_Get_Kerning(
          pointer, Integer(left_glyph_id), Integer(right_glyph_id),
          Native::FT_KERNING_DEFAULT, vector.pointer
        ),
        "FT_Get_Kerning"
      )
      FixedPoint.from_26_6(vector[:x])
    end

    def line_advance(text)
      previous = nil
      String(text).each_codepoint.sum(0.0) do |codepoint|
        id = char_index(codepoint)
        adjustment = previous ? kerning(previous, id) : 0.0
        previous = id
        adjustment + glyph_by_id(id).advance
      end
    end

    private

    def prepare_sdf!(spread)
      unless (library.version <=> [2, 11, 0]) >= 0
        raise UnsupportedError, "SDF rendering requires FreeType 2.11 or newer (found #{library.version.join('.')})"
      end
      unless spread.is_a?(Integer) && spread.between?(2, 32)
        raise ArgumentError, "spread must be an integer between 2 and 32"
      end

      value = FFI::MemoryPointer.new(:uint)
      value.write_uint(spread)
      Native.check!(Native.FT_Property_Set(library.pointer, "sdf", "spread", value), "FT_Property_Set")
    end

    def codepoint_for(character)
      return character if character.is_a?(Integer) && character.between?(0, 0x10FFFF)

      codepoints = String(character).codepoints
      raise ArgumentError, "expected exactly one Unicode codepoint" unless codepoints.length == 1

      codepoints.first
    end
  end
end
