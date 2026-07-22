# frozen_string_literal: true

require "open3"
require "shellwords"
require "tmpdir"

RSpec.describe "FreeType native ABI" do
  STRUCTS = {
    "FT_Bitmap" => {
      ruby: FreeType::Native::Bitmap,
      fields: {
        rows: "rows", width: "width", pitch: "pitch", buffer: "buffer",
        num_grays: "num_grays", pixel_mode: "pixel_mode",
        palette_mode: "palette_mode", palette: "palette"
      }
    },
    "FT_Size_Metrics" => {
      ruby: FreeType::Native::SizeMetrics,
      fields: {
        x_ppem: "x_ppem", y_ppem: "y_ppem", x_scale: "x_scale", y_scale: "y_scale",
        ascender: "ascender", descender: "descender", height: "height", max_advance: "max_advance"
      }
    },
    "FT_FaceRec" => {
      ruby: FreeType::Native::FaceRec,
      fields: {
        num_faces: "num_faces", face_index: "face_index", face_flags: "face_flags",
        style_flags: "style_flags", num_glyphs: "num_glyphs", family_name: "family_name",
        style_name: "style_name", num_fixed_sizes: "num_fixed_sizes",
        available_sizes: "available_sizes", num_charmaps: "num_charmaps", charmaps: "charmaps",
        generic: "generic", bbox: "bbox", units_per_em: "units_per_EM", ascender: "ascender",
        descender: "descender", height: "height", max_advance_width: "max_advance_width",
        max_advance_height: "max_advance_height", underline_position: "underline_position",
        underline_thickness: "underline_thickness", glyph: "glyph", size: "size", charmap: "charmap",
        driver: "driver", memory: "memory", stream: "stream", sizes_list: "sizes_list",
        autohint: "autohint", extensions: "extensions", internal: "internal"
      }
    },
    "FT_GlyphSlotRec" => {
      ruby: FreeType::Native::GlyphSlotRec,
      fields: {
        library: "library", face: "face", next: "next", glyph_index: "glyph_index", generic: "generic",
        metrics: "metrics", linear_hori_advance: "linearHoriAdvance",
        linear_vert_advance: "linearVertAdvance", advance: "advance", format: "format", bitmap: "bitmap",
        bitmap_left: "bitmap_left", bitmap_top: "bitmap_top", outline: "outline",
        num_subglyphs: "num_subglyphs", subglyphs: "subglyphs", control_data: "control_data",
        control_len: "control_len", lsb_delta: "lsb_delta", rsb_delta: "rsb_delta",
        other: "other", internal: "internal"
      }
    }
  }.freeze

  it "matches every public struct field offset and total size from the installed headers" do
    cflags, status = Open3.capture2("pkg-config", "--cflags", "freetype2")
    skip "freetype2 development headers are not installed" unless status.success?

    native_layout = compile_and_read_layout(Shellwords.split(cflags))
    STRUCTS.each do |c_name, definition|
      ruby_struct = definition.fetch(:ruby)
      expect(ruby_struct.size).to eq(native_layout.fetch("#{c_name}.$size")), "size of #{c_name}"
      definition.fetch(:fields).each do |ruby_name, c_field|
        expect(ruby_struct.offset_of(ruby_name)).to eq(native_layout.fetch("#{c_name}.#{c_field}")),
          "offset of #{c_name}.#{c_field}"
      end
    end
  end

  def compile_and_read_layout(cflags)
    Dir.mktmpdir("freetype-abi") do |directory|
      source = File.join(directory, "layout.c")
      executable = File.join(directory, "layout")
      File.write(source, c_source)
      _stdout, stderr, status = Open3.capture3("cc", source, "-o", executable, *cflags)
      raise "could not compile ABI probe: #{stderr}" unless status.success?

      stdout, run_stderr, run_status = Open3.capture3(executable)
      raise "could not run ABI probe: #{run_stderr}" unless run_status.success?

      stdout.lines.to_h { |line| key, value = line.strip.split("=", 2); [key, Integer(value)] }
    end
  end

  def c_source
    probes = STRUCTS.flat_map do |c_name, definition|
      size = %(printf("#{c_name}.$size=%zu\\n", sizeof(#{c_name}));)
      offsets = definition.fetch(:fields).values.map do |field|
        %(printf("#{c_name}.#{field}=%zu\\n", offsetof(#{c_name}, #{field}));)
      end
      [size, *offsets]
    end

    <<~C
      #include <stddef.h>
      #include <stdio.h>
      #include <ft2build.h>
      #include FT_FREETYPE_H

      int main(void) {
        #{probes.join("\n  ")}
        return 0;
      }
    C
  end
end
