# frozen_string_literal: true

require "ffi"

module FreeType
  module Native
    extend FFI::Library

    library_override = ENV["FREETYPE_LIBRARY"]
    candidates = [library_override, "freetype", "libfreetype.so.6", "libfreetype.6.dylib"].compact
    ffi_lib candidates

    FT_LOAD_DEFAULT = 0
    FT_LOAD_NO_HINTING = 1 << 1
    FT_LOAD_RENDER = 1 << 2
    FT_LOAD_TARGET_LIGHT = 1 << 16
    FT_LOAD_TARGET_MONO = 2 << 16

    FT_RENDER_MODE_NORMAL = 0
    FT_RENDER_MODE_LIGHT = 1
    FT_RENDER_MODE_MONO = 2
    FT_RENDER_MODE_SDF = 5

    FT_PIXEL_MODE_NONE = 0
    FT_PIXEL_MODE_MONO = 1
    FT_PIXEL_MODE_GRAY = 2
    FT_KERNING_DEFAULT = 0
    FT_FACE_FLAG_SCALABLE = 1 << 0
    FT_FACE_FLAG_KERNING = 1 << 6
    FT_ENCODING_UNICODE = 0x756E6963

    ERROR_NAMES = {
      0x00 => :Ok, 0x01 => :Cannot_Open_Resource, 0x02 => :Unknown_File_Format,
      0x03 => :Invalid_File_Format, 0x04 => :Invalid_Version, 0x05 => :Lower_Module_Version,
      0x06 => :Invalid_Argument, 0x07 => :Unimplemented_Feature, 0x08 => :Invalid_Table,
      0x09 => :Invalid_Offset, 0x0A => :Array_Too_Large, 0x0B => :Missing_Module,
      0x0C => :Missing_Property, 0x10 => :Invalid_Glyph_Index, 0x11 => :Invalid_Character_Code,
      0x12 => :Invalid_Glyph_Format, 0x13 => :Cannot_Render_Glyph, 0x14 => :Invalid_Outline,
      0x15 => :Invalid_Composite, 0x16 => :Too_Many_Hints, 0x17 => :Invalid_Pixel_Size,
      0x18 => :Invalid_SVG_Document, 0x20 => :Invalid_Handle, 0x21 => :Invalid_Library_Handle,
      0x22 => :Invalid_Driver_Handle, 0x23 => :Invalid_Face_Handle, 0x24 => :Invalid_Size_Handle,
      0x25 => :Invalid_Slot_Handle, 0x26 => :Invalid_CharMap_Handle, 0x27 => :Invalid_Cache_Handle,
      0x28 => :Invalid_Stream_Handle, 0x30 => :Too_Many_Drivers, 0x31 => :Too_Many_Extensions,
      0x40 => :Out_Of_Memory, 0x41 => :Unlisted_Object, 0x51 => :Cannot_Open_Stream,
      0x52 => :Invalid_Stream_Seek, 0x53 => :Invalid_Stream_Skip, 0x54 => :Invalid_Stream_Read,
      0x55 => :Invalid_Stream_Operation, 0x56 => :Invalid_Frame_Operation,
      0x57 => :Nested_Frame_Access, 0x58 => :Invalid_Frame_Read, 0x60 => :Raster_Uninitialized,
      0x61 => :Raster_Corrupted, 0x62 => :Raster_Overflow, 0x63 => :Raster_Negative_Height,
      0x70 => :Too_Many_Caches, 0x80 => :Invalid_Opcode, 0x81 => :Too_Few_Arguments,
      0x82 => :Stack_Overflow, 0x83 => :Code_Overflow, 0x84 => :Bad_Argument,
      0x85 => :Divide_By_Zero, 0x86 => :Invalid_Reference, 0x87 => :Debug_OpCode,
      0x88 => :ENDF_In_Exec_Stream, 0x89 => :Nested_DEFS, 0x8A => :Invalid_CodeRange,
      0x8B => :Execution_Too_Long, 0x8C => :Too_Many_Function_Defs,
      0x8D => :Too_Many_Instruction_Defs, 0x8E => :Table_Missing, 0x8F => :Horiz_Header_Missing,
      0x90 => :Locations_Missing, 0x91 => :Name_Table_Missing, 0x92 => :CMap_Table_Missing,
      0x93 => :Hmtx_Table_Missing, 0x94 => :Post_Table_Missing, 0x95 => :Invalid_Horiz_Metrics,
      0x96 => :Invalid_CharMap_Format, 0x97 => :Invalid_PPem, 0x98 => :Invalid_Vert_Metrics,
      0x99 => :Could_Not_Find_Context, 0x9A => :Invalid_Post_Table_Format,
      0x9B => :Invalid_Post_Table, 0x9C => :DEF_In_Glyf_Bytecode, 0x9D => :Missing_Bitmap,
      0x9E => :Missing_SVG_Hooks, 0xA0 => :Syntax_Error, 0xA1 => :Stack_Underflow,
      0xA2 => :Ignore, 0xA3 => :No_Unicode_Glyph_Name, 0xA4 => :Glyph_Too_Big,
      0xB0 => :Missing_Startfont_Field, 0xB1 => :Missing_Font_Field, 0xB2 => :Missing_Size_Field,
      0xB3 => :Missing_Fontboundingbox_Field, 0xB4 => :Missing_Chars_Field,
      0xB5 => :Missing_Startchar_Field, 0xB6 => :Missing_Encoding_Field,
      0xB7 => :Missing_Bbx_Field, 0xB8 => :Bbx_Too_Big, 0xB9 => :Corrupted_Font_Header,
      0xBA => :Corrupted_Font_Glyphs
    }.freeze

    require_relative "native/structs"

    attach_function :FT_Init_FreeType, [:pointer], :int
    attach_function :FT_Done_FreeType, [:pointer], :int
    attach_function :FT_New_Face, %i[pointer string long pointer], :int
    attach_function :FT_New_Memory_Face, %i[pointer pointer long long pointer], :int
    attach_function :FT_Done_Face, [:pointer], :int
    attach_function :FT_Set_Pixel_Sizes, %i[pointer uint uint], :int
    attach_function :FT_Set_Char_Size, %i[pointer long long uint uint], :int
    attach_function :FT_Get_Char_Index, %i[pointer ulong], :uint
    attach_function :FT_Load_Glyph, %i[pointer uint int32], :int
    attach_function :FT_Load_Char, %i[pointer ulong int32], :int
    attach_function :FT_Render_Glyph, %i[pointer int], :int
    attach_function :FT_Get_Kerning, %i[pointer uint uint uint pointer], :int
    attach_function :FT_Select_Charmap, %i[pointer int], :int
    attach_function :FT_Library_Version, %i[pointer pointer pointer pointer], :void
    attach_function :FT_Property_Set, %i[pointer string string pointer], :int

    module_function

    def check!(code, operation = nil)
      return if code.zero?

      raise NativeError.new(code, operation: operation)
    end
  end
end
