# frozen_string_literal: true

begin
  require "texel"
rescue LoadError
  # Texel is an optional integration.
end

module FreeType
  module Image
    module_function

    def build(width:, height:, data:)
      bytes = String(data).dup.force_encoding(Encoding::BINARY).freeze
      if defined?(Texel::Image) && width.positive? && height.positive?
        return Texel::Image.new(
          width: width, height: height, channels: 1, dtype: :u8,
          color_space: :linear, data: bytes
        )
      end

      { width: width, height: height, data: bytes }.freeze
    end

    def data(image)
      image.respond_to?(:data) ? image.data : image.fetch(:data)
    end
  end
end
