# frozen_string_literal: true

module FreeType
  module Native
    module Structs
      module_function

      def define(name, fields)
        klass = Class.new(FFI::Struct)
        klass.layout(*fields.flatten)
        Native.const_set(name, klass)
      end

      def define_all
        define(:Generic, data: :pointer, finalizer: :pointer)
        define(:Vector, x: :long, y: :long)
        define(:BBox, x_min: :long, y_min: :long, x_max: :long, y_max: :long)
        define(:ListRec, head: :pointer, tail: :pointer)
        define(:BitmapSize, height: :short, width: :short, size: :long, x_ppem: :long, y_ppem: :long)
        define(:GlyphMetrics,
          width: :long, height: :long,
          hori_bearing_x: :long, hori_bearing_y: :long, hori_advance: :long,
          vert_bearing_x: :long, vert_bearing_y: :long, vert_advance: :long)
        define(:Bitmap,
          rows: :uint, width: :uint, pitch: :int, buffer: :pointer,
          num_grays: :ushort, pixel_mode: :uchar, palette_mode: :uchar, palette: :pointer)
        define(:Outline,
          n_contours: :ushort, n_points: :ushort, points: :pointer,
          tags: :pointer, contours: :pointer, flags: :int)
        define(:SizeMetrics,
          x_ppem: :ushort, y_ppem: :ushort, x_scale: :long, y_scale: :long,
          ascender: :long, descender: :long, height: :long, max_advance: :long)
        define(:SizeRec,
          face: :pointer, generic: Generic.by_value, metrics: SizeMetrics.by_value, internal: :pointer)
        define(:FaceRec,
          num_faces: :long, face_index: :long, face_flags: :long, style_flags: :long,
          num_glyphs: :long, family_name: :pointer, style_name: :pointer,
          num_fixed_sizes: :int, available_sizes: :pointer, num_charmaps: :int, charmaps: :pointer,
          generic: Generic.by_value, bbox: BBox.by_value, units_per_em: :ushort,
          ascender: :short, descender: :short, height: :short,
          max_advance_width: :short, max_advance_height: :short,
          underline_position: :short, underline_thickness: :short,
          glyph: :pointer, size: :pointer, charmap: :pointer,
          driver: :pointer, memory: :pointer, stream: :pointer,
          sizes_list: ListRec.by_value, autohint: Generic.by_value,
          extensions: :pointer, internal: :pointer)
        define(:GlyphSlotRec,
          library: :pointer, face: :pointer, next: :pointer, glyph_index: :uint,
          generic: Generic.by_value, metrics: GlyphMetrics.by_value,
          linear_hori_advance: :long, linear_vert_advance: :long, advance: Vector.by_value,
          format: :uint, bitmap: Bitmap.by_value, bitmap_left: :int, bitmap_top: :int,
          outline: Outline.by_value, num_subglyphs: :uint, subglyphs: :pointer,
          control_data: :pointer, control_len: :long, lsb_delta: :long, rsb_delta: :long,
          other: :pointer, internal: :pointer)
      end
    end

    Structs.define_all

    FT_Generic = Generic
    FT_Vector = Vector
    FT_BBox = BBox
    FT_ListRec = ListRec
    FT_Bitmap_Size = BitmapSize
    FT_Glyph_Metrics = GlyphMetrics
    FT_Bitmap = Bitmap
    FT_Outline = Outline
    FT_Size_Metrics = SizeMetrics
    FT_SizeRec = SizeRec
    FT_FaceRec = FaceRec
    FT_GlyphSlotRec = GlyphSlotRec
  end
end
