# frozen_string_literal: true

require "digest"

RSpec.describe FreeType do
  let(:font_path) { File.expand_path("fixtures/ABeeZee-Regular.ttf", __dir__) }

  it "exposes a version and the legacy constant alias" do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    expect(Freetype).to equal(described_class)
  end

  it "converts both public fixed-point formats to floats" do
    expect(described_class::FixedPoint.from_26_6(96)).to eq(1.5)
    expect(described_class::FixedPoint.from_26_6(-32)).to eq(-0.5)
    expect(described_class::FixedPoint.from_16_16(98_304)).to eq(1.5)
  end

  it "includes the symbolic FreeType error name" do
    error = described_class::NativeError.new(0x01, operation: "FT_New_Face")

    expect(error.code).to eq(0x01)
    expect(error.name).to eq(:Cannot_Open_Resource)
    expect(error.message).to include("FT_New_Face", "Cannot_Open_Resource")
    expect(described_class::Native::FT_Err_Cannot_Open_Resource).to eq(0x01)
    expect(described_class::Native::ERROR_CODES[:Cannot_Open_Resource]).to eq(0x01)
  end

  describe FreeType::Library do
    it "reports the native version and closes around a block" do
      library = nil
      version = described_class.open do |opened|
        library = opened
        opened.version
      end

      expect(version).to match([Integer, Integer, Integer])
      expect(version.first).to be >= 2
      expect(library).to be_closed
    end

    it "closes its faces before the library" do
      library = described_class.new
      face = library.face(font_path)

      library.close

      expect(face).to be_closed
      expect(library).to be_closed
      expect { face.family_name }.to raise_error(FreeType::ClosedError)
    end
  end

  describe FreeType::Face do
    around do |example|
      FreeType.open do |library|
        library.face(font_path) do |face|
          @library = library
          @face = face
          example.run
        end
      end
    end

    it "reads face metadata and scaled metrics" do
      expect([@face.family_name, @face.style_name]).to eq(["ABeeZee", "Regular"])
      expect(@face.units_per_em).to eq(1000)
      expect(@face.glyph_count).to eq(268)
      expect(@face).to be_scalable
      expect(@face).not_to have_kerning

      @face.set_pixel_size(32)
      expect(@face.metrics).to eq(
        FreeType::Metrics.new(ascender: 30.0, descender: -9.0, line_height: 38.0, max_advance: 34.0)
      )
    end

    it "loads a path face and a retained memory face identically" do
      bytes = File.binread(font_path)
      memory_face = @library.face(bytes)
      bytes.replace("discarded by caller")

      expect(memory_face.family_name).to eq(@face.family_name)
      expect(memory_face.source_bytes.bytesize).to eq(File.size(font_path))
      expect(memory_face.source_bytes).to be_frozen
    ensure
      memory_face&.close
    end

    it "rasterizes gray and mono glyphs with pixel metrics" do
      @face.set_pixel_size(32)
      gray = @face.glyph("A")
      mono = @face.glyph_by_id(gray.id, mode: :mono)

      expect([gray.id, gray.width, gray.height, gray.bearing_x, gray.bearing_y, gray.advance])
        .to eq([1, 22, 23, 0.0, 22.0, 21.0])
      expect(FreeType::Image.data(gray.bitmap).bytesize).to eq(gray.width * gray.height)
      expect(FreeType::Image.data(mono.bitmap).bytes.uniq).to contain_exactly(0, 255)
      expect(FreeType::Image.data(mono.bitmap).bytesize).to eq(mono.width * mono.height)
      expect(gray.raw).to be_a(FreeType::Native::GlyphSlotRec)
    end

    it "matches the bitmap golden for the installed FreeType release" do
      skip "golden is recorded for FreeType 2.14" unless @library.version.take(2) == [2, 14]

      @face.set_pixel_size(32)
      digest = Digest::SHA256.hexdigest(FreeType::Image.data(@face.glyph("A").bitmap))
      expect(digest).to eq("7fa39a3d97797107287169a3ae35e86f584a5bf63bdea39eb0f5d46aabf73fd4")
    end

    it "uses glyph IDs for kerning and simple line advance" do
      @face.set_pixel_size(32)
      left = @face.char_index("A")
      right = @face.char_index("V")

      expect(@face.kerning(left, right)).to eq(0.0)
      expect(@face.line_advance("AV")).to eq(41.0)
    end

    it "rejects SDF on FreeType older than 2.11" do
      @face.set_pixel_size(32)
      allow(@library).to receive(:version).and_return([2, 10, 4])

      expect { @face.glyph("A", mode: :sdf) }
        .to raise_error(FreeType::UnsupportedError, /2\.11/)
    end

    it "renders SDF on a supported FreeType" do
      skip "SDF requires FreeType 2.11" if (@library.version <=> [2, 11, 0]).negative?

      @face.set_pixel_size(32)
      glyph = @face.glyph("A", mode: :sdf, spread: 8)
      expect(glyph.width).to be > 22
      expect(glyph.height).to be > 23
      expect(FreeType::Image.data(glyph.bitmap).bytesize).to eq(glyph.width * glyph.height)
    end
  end

  describe FreeType::Charset do
    it "ships standard character sets" do
      expect(described_class::ASCII.size).to eq(95)
      expect(described_class::LATIN1.size).to eq(224)
      expect(described_class::KANA).to include("あ", "ア")
      expect(described_class::JOYO_KANJI.size).to eq(2136)
      expect(described_class::JOYO_KANJI.uniq.size).to eq(2136)
    end
  end
end
