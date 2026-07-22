# frozen_string_literal: true

# Usage: bundle exec ruby examples/stagecraft_text.rb FONT_PATH [TEXT]
#
# Stagecraft's GPU backend is intentionally isolated behind the four-method
# adapter below. Map these calls to the backend version used by the host app;
# the FreeType/HarfBuzz side remains unchanged.

require "freetype/harfbuzz"
require "stagecraft"

class StagecraftTextRenderer
  def initialize(stage, atlas, packed)
    width = atlas.image.respond_to?(:width) ? atlas.image.width : atlas.image.fetch(:width)
    height = atlas.image.respond_to?(:height) ? atlas.image.height : atlas.image.fetch(:height)
    @stage = stage
    @texture = stage.texture_2d(
      width: width, height: height, format: :r8_unorm,
      data: FreeType::Image.data(atlas.image)
    )
    @mesh = stage.indexed_mesh(
      vertices: packed.fetch(:vertices), indices: packed.fetch(:indices),
      vertex_stride: 16,
      attributes: { position: [:float32x2, 0], uv: [:float32x2, 8] },
      index_format: :uint16
    )
    @material = stage.sdf_text_material(texture: @texture, edge: 0.5, softness: 0.1)
  end

  def draw
    @stage.draw_indexed(mesh: @mesh, material: @material)
  end
end

font_path = ARGV[0] || abort("usage: #{$PROGRAM_NAME} FONT_PATH [TEXT]")
text = ARGV[1] || "FreeType + HarfBuzz + Stagecraft"
font_size = 64

blob = HarfBuzz::Blob.from_file!(font_path)
hb_face = HarfBuzz::Face.new(blob, 0)
hb_font = HarfBuzz::Font.new(hb_face)
hb_font.scale = [font_size * 64, font_size * 64]
hb_font.ppem = [font_size, font_size]
buffer = HarfBuzz::Buffer.new
buffer.add_utf8(text)
buffer.guess_segment_properties
HarfBuzz.shape(hb_font, buffer)

FreeType.open do |library|
  library.face(font_path) do |face|
    atlas = FreeType::Atlas.build(
      face, glyph_ids: buffer.glyph_infos.map(&:glyph_id),
      size: font_size, mode: :sdf, padding: 2, max_width: 1024
    )
    packed = FreeType::TextRun.layout(buffer, atlas).to_packed

    Stagecraft.run(title: "FreeType SDF text", width: 960, height: 320) do |stage|
      renderer = StagecraftTextRenderer.new(stage, atlas, packed)
      stage.frame { renderer.draw }
    end
  end
end
