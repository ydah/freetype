# frozen_string_literal: true

module FreeType
  module BitmapConverter
    module_function

    def copy(bitmap)
      width = bitmap[:width]
      rows = bitmap[:rows]
      return "".b.freeze if width.zero? || rows.zero?

      buffer = bitmap[:buffer]
      raise StateError, "FreeType returned a null bitmap buffer" if buffer.null?

      case bitmap[:pixel_mode]
      when Native::FT_PIXEL_MODE_GRAY
        copy_gray(buffer, width, rows, bitmap[:pitch])
      when Native::FT_PIXEL_MODE_MONO
        copy_mono(buffer, width, rows, bitmap[:pitch])
      else
        raise UnsupportedError, "unsupported FreeType pixel mode #{bitmap[:pixel_mode]}"
      end.freeze
    end

    def copy_gray(buffer, width, rows, pitch)
      rows.times.each_with_object(String.new(capacity: width * rows, encoding: Encoding::BINARY)) do |row, data|
        data << row_pointer(buffer, row, pitch).get_bytes(0, width)
      end
    end

    def copy_mono(buffer, width, rows, pitch)
      packed_width = (width + 7) / 8
      rows.times.each_with_object(String.new(capacity: width * rows, encoding: Encoding::BINARY)) do |row, data|
        packed = row_pointer(buffer, row, pitch).get_bytes(0, packed_width)
        width.times do |column|
          byte = packed.getbyte(column / 8)
          data << ((byte & (0x80 >> (column % 8))).zero? ? 0 : 255)
        end
      end
    end

    def row_pointer(buffer, row, pitch)
      FFI::Pointer.new(:uchar, buffer.address + (row * pitch))
    end
  end
end
