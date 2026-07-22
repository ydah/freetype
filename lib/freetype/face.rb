# frozen_string_literal: true

module FreeType
  class Face
    RENDER_MODES = {
      gray: Native::FT_RENDER_MODE_NORMAL,
      normal: Native::FT_RENDER_MODE_NORMAL,
      mono: Native::FT_RENDER_MODE_MONO,
      sdf: Native::FT_RENDER_MODE_SDF
    }.freeze

    attr_reader :library, :pointer, :source_bytes

    def initialize(library, source, face_index: 0)
      @library = library
      @state = { closed: false }
      @pointer = create_face(source, face_index)
      @state[:pointer] = @pointer
      ObjectSpace.define_finalizer(self, self.class.finalizer(@state))
    rescue StandardError
      @memory = nil
      @source_bytes = nil
      raise
    end

    def self.finalizer(state)
      proc do
        next if state[:closed] || !state[:pointer]

        Native.FT_Done_Face(state[:pointer])
        state[:closed] = true
      end
    end

    def close
      return if closed?

      Native.check!(Native.FT_Done_Face(pointer), "FT_Done_Face")
      @state[:closed] = true
      library.__send__(:unregister, self)
      @memory = nil
      @source_bytes = nil
      nil
    end

    def closed?
      @state[:closed]
    end

    def raw
      ensure_open!
      Native::FaceRec.new(pointer)
    end

    def family_name
      read_string(raw[:family_name])
    end

    def style_name
      read_string(raw[:style_name])
    end

    def units_per_em
      raw[:units_per_em]
    end

    def glyph_count
      raw[:num_glyphs]
    end

    def scalable?
      (raw[:face_flags] & Native::FT_FACE_FLAG_SCALABLE) != 0
    end

    def has_kerning?
      (raw[:face_flags] & Native::FT_FACE_FLAG_KERNING) != 0
    end

    def set_pixel_size(height, width: 0)
      ensure_open!
      validate_positive_integer!(height, "height")
      raise ArgumentError, "width must be a non-negative integer" unless width.is_a?(Integer) && width >= 0

      Native.check!(Native.FT_Set_Pixel_Sizes(pointer, width, height), "FT_Set_Pixel_Sizes")
      self
    end

    def set_char_size(pt:, dpi: 96, width: 0, horizontal_dpi: dpi)
      ensure_open!
      validate_positive_number!(pt, "pt")
      validate_positive_integer!(dpi, "dpi")
      raise ArgumentError, "width must be non-negative" unless width.is_a?(Numeric) && width >= 0
      validate_positive_integer!(horizontal_dpi, "horizontal_dpi")

      Native.check!(
        Native.FT_Set_Char_Size(pointer, (width * 64).round, (pt * 64).round, horizontal_dpi, dpi),
        "FT_Set_Char_Size"
      )
      self
    end

    def select_charmap(encoding = :unicode)
      ensure_open!
      native_encoding = encoding == :unicode ? Native::FT_ENCODING_UNICODE : Integer(encoding)
      Native.check!(Native.FT_Select_Charmap(pointer, native_encoding), "FT_Select_Charmap")
      self
    end

    def metrics
      size_pointer = raw[:size]
      raise StateError, "set a face size before reading metrics" if size_pointer.null?

      native = Native::SizeRec.new(size_pointer)[:metrics]
      Metrics.new(
        ascender: FixedPoint.from_26_6(native[:ascender]),
        descender: FixedPoint.from_26_6(native[:descender]),
        line_height: FixedPoint.from_26_6(native[:height]),
        max_advance: FixedPoint.from_26_6(native[:max_advance])
      )
    end

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

      render_mode = RENDER_MODES.fetch(mode) { raise ArgumentError, "unknown render mode #{mode.inspect}" }
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

    def native_state
      @state
    end

    def create_face(source, face_index)
      output = FFI::MemoryPointer.new(:pointer)
      index = Integer(face_index)
      if path_source?(source)
        path = source.respond_to?(:to_path) ? source.to_path : source
        Native.check!(Native.FT_New_Face(library.pointer, path.to_s, index, output), "FT_New_Face")
      else
        retain_memory_source(source)
        Native.check!(
          Native.FT_New_Memory_Face(library.pointer, @memory, @source_bytes.bytesize, index, output),
          "FT_New_Memory_Face"
        )
      end
      output.read_pointer
    end

    def path_source?(source)
      return true if source.respond_to?(:to_path)
      return false unless source.is_a?(String)
      return false if source.encoding == Encoding::BINARY || source.include?("\0")
      return true if File.file?(source)

      source.match?(/\.(?:ttf|ttc|otf|otc|woff2?)\z/i) || source.include?(File::SEPARATOR)
    end

    def retain_memory_source(source)
      @source_bytes = String(source).dup.force_encoding(Encoding::BINARY).freeze
      raise ArgumentError, "font bytes cannot be empty" if @source_bytes.empty?

      @memory = FFI::MemoryPointer.new(:uchar, @source_bytes.bytesize)
      @memory.put_bytes(0, @source_bytes)
    end

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

    def read_string(native_pointer)
      native_pointer.null? ? nil : native_pointer.read_string.force_encoding(Encoding::UTF_8)
    end

    def validate_positive_number!(value, name)
      return if value.is_a?(Numeric) && value.positive?

      raise ArgumentError, "#{name} must be positive"
    end

    def validate_positive_integer!(value, name)
      return if value.is_a?(Integer) && value.positive?

      raise ArgumentError, "#{name} must be a positive integer"
    end

    def ensure_open!
      raise ClosedError, "face is closed" if closed?
      raise ClosedError, "library is closed" if library.closed?
    end
  end
end
