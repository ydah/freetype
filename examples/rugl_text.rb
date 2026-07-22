# frozen_string_literal: true

# Usage: bundle exec ruby examples/rugl_text.rb FONT_PATH [TEXT]

require "freetype/harfbuzz"
require "rugl"

font_path = ARGV[0] || abort("usage: #{$PROGRAM_NAME} FONT_PATH [TEXT]")
text = ARGV[1] || "FreeType + HarfBuzz + Rugl"
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
    ids = buffer.glyph_infos.map(&:glyph_id)
    atlas = FreeType::Atlas.build(
      face, glyph_ids: ids, size: font_size, mode: :sdf,
      padding: 2, max_width: 1024
    )
    packed = FreeType::TextRun.layout(buffer, atlas).to_packed

    atlas_data = FreeType::Image.data(atlas.image)
    rgba = atlas_data.each_byte.each_with_object(String.new(capacity: atlas_data.bytesize * 4).b) do |alpha, bytes|
      bytes << 255 << 255 << 255 << alpha
    end
    image_width = atlas.image.respond_to?(:width) ? atlas.image.width : atlas.image.fetch(:width)
    image_height = atlas.image.respond_to?(:height) ? atlas.image.height : atlas.image.fetch(:height)

    rugl = Rugl.create(width: 960, height: 320, title: "FreeType SDF text")
    vertices = rugl.buffer(data: packed.fetch(:vertices), type: :float)
    indices = rugl.elements(data: packed.fetch(:indices).unpack("S<*"), type: :uint16)
    texture = rugl.texture(
      width: image_width, height: image_height, format: :rgba,
      type: :uint8, data: rgba, min_filter: :linear, mag_filter: :linear
    )

    draw_text = rugl.command(
      vert: <<~GLSL,
        #version 410 core
        layout(location = 0) in vec2 position;
        layout(location = 1) in vec2 uv;
        uniform vec2 viewport;
        uniform vec2 origin;
        out vec2 text_uv;
        void main() {
          vec2 pixel = position + origin;
          vec2 clip = vec2(pixel.x / viewport.x * 2.0 - 1.0,
                           1.0 - pixel.y / viewport.y * 2.0);
          gl_Position = vec4(clip, 0.0, 1.0);
          text_uv = uv;
        }
      GLSL
      frag: <<~GLSL,
        #version 410 core
        in vec2 text_uv;
        uniform sampler2D atlas_texture;
        out vec4 frag_color;
        void main() {
          float distance_value = texture(atlas_texture, text_uv).a;
          float alpha = smoothstep(0.45, 0.55, distance_value);
          frag_color = vec4(0.92, 0.95, 1.0, alpha);
        }
      GLSL
      attributes: {
        position: { buffer: vertices, size: 2, stride: 16, offset: 0 },
        uv: { buffer: vertices, size: 2, stride: 16, offset: 8 }
      },
      uniforms: {
        viewport: [960.0, 320.0],
        origin: [48.0, 150.0],
        atlas_texture: texture
      },
      elements: indices,
      blend: { enable: true, func: { src: :src_alpha, dst: :one_minus_src_alpha } }
    )

    rugl.frame do
      rugl.clear(color: [0.025, 0.035, 0.06, 1.0])
      draw_text.call
    end
  end
end
