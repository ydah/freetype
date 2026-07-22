# frozen_string_literal: true

module FreeType
  module Charset
    ASCII = (0x20..0x7E).map { |codepoint| [codepoint].pack("U") }.freeze
    LATIN1 = (0x20..0xFF).map { |codepoint| [codepoint].pack("U") }.freeze
    KANA = [*(0x3040..0x309F), *(0x30A0..0x30FF)].map { |codepoint| [codepoint].pack("U") }.freeze

    joyo_path = File.expand_path("data/joyo_kanji.txt", __dir__)
    JOYO_KANJI = File.read(joyo_path, encoding: Encoding::UTF_8)
      .each_char.reject { |character| character.match?(/\s/) }.freeze
  end
end
