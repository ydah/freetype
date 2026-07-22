# frozen_string_literal: true

require_relative "../lib/freetype/text_run"

RSpec.describe FreeType::TextRun do
  Info = Data.define(:glyph_id)
  Position = Data.define(:x_advance, :y_advance, :x_offset, :y_offset)
  Shaped = Data.define(:glyph_infos, :glyph_positions)
  TestAtlas = Data.define(:entries)

  let(:entries) do
    {
      1 => FreeType::Atlas::Entry.new(
        u0: 0.0, v0: 0.0, u1: 0.25, v1: 0.5,
        bearing_x: 1.0, bearing_y: 5.0, width: 4, height: 6, advance: 7.0
      ),
      2 => FreeType::Atlas::Entry.new(
        u0: 0.25, v0: 0.0, u1: 0.5, v1: 0.5,
        bearing_x: 0.0, bearing_y: 4.0, width: 3, height: 5, advance: 6.0
      )
    }
  end

  it "combines HarfBuzz 26.6 positions with atlas bearings in y-down coordinates" do
    shaped = Shaped.new(
      glyph_infos: [Info.new(glyph_id: 1), Info.new(glyph_id: 2)],
      glyph_positions: [
        Position.new(x_advance: 448, y_advance: 0, x_offset: 32, y_offset: 64),
        Position.new(x_advance: 384, y_advance: 0, x_offset: 0, y_offset: 0)
      ]
    )

    run = described_class.layout(shaped, TestAtlas.new(entries: entries))

    expect(run.length).to eq(2)
    expect(run[0]).to eq(
      described_class::Quad.new(x0: 1.5, y0: -6.0, x1: 5.5, y1: 0.0,
        u0: 0.0, v0: 0.0, u1: 0.25, v1: 0.5)
    )
    expect(run[1].x0).to eq(7.0)
    expect(run[1].y0).to eq(-4.0)
  end

  it "advances over glyphs that are absent from the atlas" do
    shaped = Shaped.new(
      glyph_infos: [Info.new(glyph_id: 99), Info.new(glyph_id: 2)],
      glyph_positions: [
        Position.new(x_advance: 128, y_advance: 0, x_offset: 0, y_offset: 0),
        Position.new(x_advance: 64, y_advance: 0, x_offset: 0, y_offset: 0)
      ]
    )

    run = described_class.layout(shaped, TestAtlas.new(entries: entries))

    expect(run.length).to eq(1)
    expect(run[0].x0).to eq(2.0)
  end

  it "does not emit degenerate quads for whitespace bitmaps" do
    whitespace = FreeType::Atlas::Entry.new(
      u0: 0.0, v0: 0.0, u1: 0.0, v1: 0.0,
      bearing_x: 0.0, bearing_y: 0.0, width: 0, height: 0, advance: 4.0
    )
    shaped = Shaped.new(
      glyph_infos: [Info.new(glyph_id: 3), Info.new(glyph_id: 2)],
      glyph_positions: [
        Position.new(x_advance: 256, y_advance: 0, x_offset: 0, y_offset: 0),
        Position.new(x_advance: 64, y_advance: 0, x_offset: 0, y_offset: 0)
      ]
    )

    run = described_class.layout(shaped, TestAtlas.new(entries: entries.merge(3 => whitespace)))

    expect(run.length).to eq(1)
    expect(run[0].x0).to eq(4.0)
  end

  it "packs four f32 vertices and six u16 indices per quad" do
    shaped = Shaped.new(
      glyph_infos: [Info.new(glyph_id: 1)],
      glyph_positions: [Position.new(x_advance: 448, y_advance: 0, x_offset: 0, y_offset: 0)]
    )
    packed = described_class.layout(shaped, TestAtlas.new(entries: entries)).to_packed

    expect(packed[:vertices].bytesize).to eq(4 * 4 * 4)
    expect(packed[:indices].bytesize).to eq(6 * 2)
    expect(packed[:vertices].unpack("e*")).to eq([
      1.0, -5.0, 0.0, 0.0,
      5.0, -5.0, 0.25, 0.0,
      5.0, 1.0, 0.25, 0.5,
      1.0, 1.0, 0.0, 0.5
    ])
    expect(packed[:indices].unpack("S<*")).to eq([0, 1, 2, 0, 2, 3])
    expect(packed.values).to all(be_frozen)
  end
end
