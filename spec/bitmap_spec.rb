# frozen_string_literal: true

RSpec.describe FreeType::BitmapConverter do
  def bitmap(buffer, width:, rows:, pitch:, mode: FreeType::Native::FT_PIXEL_MODE_GRAY)
    described_class = FreeType::Native::Bitmap
    described_class.new.tap do |value|
      value[:width] = width
      value[:rows] = rows
      value[:pitch] = pitch
      value[:buffer] = buffer
      value[:pixel_mode] = mode
    end
  end

  it "removes positive row pitch padding" do
    memory = FFI::MemoryPointer.new(:uchar, 8)
    memory.put_bytes(0, "abcXdefY")

    expect(described_class.copy(bitmap(memory, width: 3, rows: 2, pitch: 4))).to eq("abcdef")
  end

  it "normalizes a negative bottom-up pitch" do
    memory = FFI::MemoryPointer.new(:uchar, 8)
    memory.put_bytes(0, "defYabcX")
    top_row = memory + 4

    expect(described_class.copy(bitmap(top_row, width: 3, rows: 2, pitch: -4))).to eq("abcdef")
  end

  it "expands one-bit mono pixels to u8" do
    memory = FFI::MemoryPointer.new(:uchar, 4)
    memory.put_array_of_uint8(0, [0b1010_0000, 0, 0b0101_0000, 0])
    native = bitmap(
      memory, width: 4, rows: 2, pitch: 2,
      mode: FreeType::Native::FT_PIXEL_MODE_MONO
    )

    expect(described_class.copy(native).bytes).to eq([255, 0, 255, 0, 0, 255, 0, 255])
  end
end
