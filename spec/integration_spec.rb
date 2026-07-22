# frozen_string_literal: true

require "freetype/harfbuzz"

RSpec.describe "optional gem integrations" do
  let(:font_path) { File.expand_path("fixtures/ABeeZee-Regular.ttf", __dir__) }

  it "returns an immutable one-channel Texel image for rendered glyphs" do
    FreeType.open do |library|
      library.face(font_path) do |face|
        face.set_pixel_size(32)
        image = face.glyph("A").bitmap

        expect(image).to be_a(Texel::Image)
        expect([image.width, image.height]).to eq([22, 23])
        expect([image.channels, image.dtype, image.color_space]).to eq([1, :u8, :linear])
        expect(image.data).to be_frozen
        expect(image.data.bytesize).to eq(image.width * image.height)
      end
    end
  end

  it "turns real harfbuzz-ruby output into a packed atlas text mesh" do
    font_size = 32
    blob = HarfBuzz::Blob.from_file!(font_path)
    hb_face = HarfBuzz::Face.new(blob, 0)
    hb_font = HarfBuzz::Font.new(hb_face)
    hb_font.scale = [font_size * 64, font_size * 64]
    hb_font.ppem = [font_size, font_size]
    buffer = HarfBuzz::Buffer.new
    buffer.add_utf8("AV Ruby")
    buffer.guess_segment_properties
    HarfBuzz.shape(hb_font, buffer)

    FreeType.open do |library|
      library.face(font_path) do |face|
        atlas = FreeType::Atlas.build(
          face,
          glyph_ids: buffer.glyph_infos.map(&:glyph_id),
          size: font_size,
          max_width: 256
        )
        run = FreeType::TextRun.layout(buffer, atlas)
        packed = run.to_packed

        expect(buffer.length).to eq(7)
        expect(run.length).to eq(6) # The space advances without emitting a degenerate quad.
        expect(packed[:vertices].bytesize).to eq(6 * 4 * 4 * 4)
        expect(packed[:indices].bytesize).to eq(6 * 6 * 2)
      end
    end
  end
end
