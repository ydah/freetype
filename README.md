# freetype

Ruby FFI bindings for FreeType 2.11 and newer. The public API converts all
FreeType 26.6 and 16.16 fixed-point values to pixel `Float`s and provides the
rasterization half of a shape → rasterize → atlas → GPU text pipeline.

## Requirements

- Ruby 3.2 or newer
- A system FreeType library (2.11 or newer for SDF rendering)
- The `ffi` gem
- Optional: `texel` for `Texel::Image` bitmap values
- Optional: `harfbuzz-ruby` for shaped text meshes
- Optional: `rugl` plus GLFW/OpenGL for the GPU example

Install FreeType with the platform package manager, then add the gem:

```sh
bundle add freetype
```

The native loader searches `freetype`, `libfreetype.so.6`, and
`libfreetype.6.dylib`. Set `FREETYPE_LIBRARY` to an explicit shared-library
path when the system loader cannot find it.

## Faces and glyphs

```ruby
require "freetype"

FreeType.open do |library|
  library.face("NotoSansJP-Regular.ttf") do |face|
    face.set_pixel_size(32)

    p face.family_name
    p face.style_name
    p face.metrics # ascender, descender, line_height, max_advance in pixels

    glyph = face.glyph("あ")
    glyph = face.glyph_by_id(1234) # use this for HarfBuzz output
    p [glyph.width, glyph.height, glyph.bearing_x, glyph.bearing_y, glyph.advance]
  end
end
```

`Library#face` also accepts font bytes. A memory face retains its own frozen
copy for the full face lifetime because FreeType does not copy the source:

```ruby
font_bytes = File.binread("font.ttf")
face = library.face(font_bytes)
```

Use `set_char_size(pt: 12, dpi: 96)` for point sizes. `Face#kerning` accepts
two glyph IDs. `Face#line_advance` is a small unshaped helper for simple text;
use HarfBuzz for script shaping, bidi text, and production layout.

The normal bitmap is an immutable `Texel::Image` with one `:u8` channel and
`:linear` color space when Texel is installed. Otherwise it is an immutable
`{ width:, height:, data: }` hash. Mono bitmaps are expanded to byte values
0 and 255, and all row pitch padding and bottom-up storage are normalized.

## SDF and atlases

```ruby
glyph = face.glyph("A", mode: :sdf, spread: 8)

atlas = FreeType::Atlas.build(
  face,
  chars: FreeType::Charset::ASCII + "こんにちは世界".chars,
  size: 48,
  mode: :sdf,
  padding: 2,
  max_width: 1024
)

atlas.image   # one-channel u8 image; both dimensions are powers of two
atlas.entries # glyph ID => normalized UV and pixel metrics
atlas.metrics
atlas.missing
```

Pass `glyph_ids:` instead of `chars:` when shaping has already produced glyph
IDs. `Charset` includes `ASCII`, `LATIN1`, `KANA`, and the 2,136-character
`JOYO_KANJI` set. SDF rendering raises `FreeType::UnsupportedError` on
FreeType older than 2.11.

## HarfBuzz text meshes

Load the optional integration and configure the HarfBuzz font at 26.6 pixel
scale. This makes its advances and offsets use the same coordinate system as
the FreeType atlas:

```ruby
require "freetype/harfbuzz"

size = 48
hb_font.scale = [size * 64, size * 64]
hb_font.ppem = [size, size]

buffer = HarfBuzz::Buffer.new
buffer.add_utf8("グラフィックス強化中")
buffer.guess_segment_properties
HarfBuzz.shape(hb_font, buffer)

atlas = FreeType::Atlas.build(
  face,
  glyph_ids: buffer.glyph_infos.map(&:glyph_id),
  size: size,
  mode: :sdf
)
run = FreeType::TextRun.layout(buffer, atlas)
packed = run.to_packed

packed[:vertices] # little-endian f32 (x, y, u, v), four vertices per quad
packed[:indices]  # little-endian u16, six indices per quad
```

Quads use a baseline origin with y increasing downward. Missing atlas entries
do not emit a quad, but their HarfBuzz advances still move the cursor. See
[`examples/rugl_text.rb`](examples/rugl_text.rb) and
[`examples/stagecraft_text.rb`](examples/stagecraft_text.rb) for GPU handoff.

The Rugl example opens a real GLFW/OpenGL window. Its one-frame smoke mode
renders the SDF text, reads back the physical framebuffer (including HiDPI
framebuffers), and fails if no text pixels were produced:

```sh
FREETYPE_RUGL_SMOKE=1 bundle exec ruby \
  examples/rugl_text.rb spec/fixtures/ABeeZee-Regular.ttf "GPU smoke"
```

The Stagecraft example remains an adapter contract because no public
Stagecraft Ruby package/API is available. Its syntax and adapter boundary are
tested; the example exits with an explicit message instead of claiming an
unverified integration. It must be validated and adjusted when the real API is
published.

## Threading and lifetime

A FreeType library must not be shared by concurrent threads. Use one
`FreeType::Library` per thread, or use `FreeType::Pool`, which keeps a
thread-local library and face cache:

```ruby
pool = FreeType::Pool.new
face = pool.face("font.ttf") # cached only in the current thread
# use pool independently from worker threads
pool.close
```

Closing a library first closes every live face. Closing is idempotent. A
glyph bitmap is copied immediately because the native slot is overwritten by
the next glyph load. `Glyph#raw` intentionally exposes that transient native
slot for callers that need native fields.

## Development

```sh
bundle install
bundle exec rake spec
```

The test suite includes an OFL font, bitmap goldens, pitch and fixed-point
tests, SDF coverage, atlas geometry checks, and a compiled ABI probe that
compares every field offset and total size of the public FreeType structs. CI
tests Ruby 3.2, 3.3, 3.4, 4.0, and head; builds FreeType 2.11.1 and 2.14.3 from
checksum-verified official sources; exercises real HarfBuzz and Texel gems;
and runs the Rugl readback test with Mesa under Xvfb. Ruby head is an
experimental compatibility signal and does not block stable releases.

## License

The gem is available under the MIT License. The bundled ABeeZee test font is
distributed under the SIL Open Font License; see `spec/fixtures/OFL.txt`.
