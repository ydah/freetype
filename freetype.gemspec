# frozen_string_literal: true

require_relative "lib/freetype/version"

Gem::Specification.new do |spec|
  spec.name = "freetype-ruby"
  spec.version = FreeType::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Ruby bindings for FreeType font rasterization"
  spec.description = <<~DESCRIPTION.strip
    freetype provides safe, fixed-point-free Ruby APIs for loading fonts,
    rasterizing glyphs, building GPU atlases, and laying out HarfBuzz output.
  DESCRIPTION
  spec.homepage = "https://github.com/ydah/freetype"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ffi", ">= 1.16", "< 2"
end
