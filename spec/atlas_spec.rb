# frozen_string_literal: true

RSpec.describe FreeType::Atlas do
  let(:font_path) { File.expand_path("fixtures/ABeeZee-Regular.ttf", __dir__) }

  it "packs non-overlapping glyphs into a power-of-two image" do
    FreeType.open do |library|
      library.face(font_path) do |face|
        atlas = described_class.build(face, chars: %w[A B C D], size: 32, padding: 2, max_width: 64)
        width = image_dimension(atlas.image, :width)
        height = image_dimension(atlas.image, :height)
        rectangles = atlas.entries.values.map do |entry|
          x = (entry.u0 * width).round
          y = (entry.v0 * height).round
          [x, y, x + entry.width, y + entry.height]
        end

        expect(width).to eq(64)
        expect(power_of_two?(height)).to be(true)
        expect(FreeType::Image.data(atlas.image).bytesize).to eq(width * height)
        expect(atlas.missing).to be_empty
        expect(rectangles).to all(satisfy { |x0, y0, x1, y1| x0 >= 0 && y0 >= 0 && x1 <= width && y1 <= height })
        rectangles.combination(2).each do |left, right|
          expect(overlap?(left, right)).to be(false)
        end
        atlas.entries.each_value do |entry|
          expect(((entry.u1 - entry.u0) * width).round).to eq(entry.width)
          expect(((entry.v1 - entry.v0) * height).round).to eq(entry.height)
        end
      end
    end
  end

  it "keeps the rounded image width within a non-power-of-two maximum" do
    FreeType.open do |library|
      library.face(font_path) do |face|
        atlas = described_class.build(face, chars: %w[A B C], size: 16, padding: 1, max_width: 50)

        expect(image_dimension(atlas.image, :width)).to be <= 50
        expect(power_of_two?(image_dimension(atlas.image, :width))).to be(true)
      end
    end
  end

  def image_dimension(image, key)
    image.respond_to?(key) ? image.public_send(key) : image.fetch(key)
  end

  def power_of_two?(value)
    value.positive? && (value & (value - 1)).zero?
  end

  def overlap?(left, right)
    left[0] < right[2] && right[0] < left[2] && left[1] < right[3] && right[1] < left[3]
  end
end
