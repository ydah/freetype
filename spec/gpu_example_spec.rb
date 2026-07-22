# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "Rugl example", :gpu do
  it "draws SDF text into a real OpenGL framebuffer" do
    root = File.expand_path("..", __dir__)
    example = File.join(root, "examples/rugl_text.rb")
    font = File.join(__dir__, "fixtures/ABeeZee-Regular.ttf")
    env = { "FREETYPE_RUGL_SMOKE" => "1" }
    stdout, stderr, status = Open3.capture3(
      env,
      RbConfig.ruby,
      example,
      font,
      "GPU smoke",
      chdir: root
    )

    expect(status).to be_success, <<~MESSAGE
      Rugl example failed.
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MESSAGE
    expect(stdout).to include("Rugl GPU smoke passed")
  end
end
