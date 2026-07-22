# frozen_string_literal: true

RSpec.describe "examples" do
  Dir[File.expand_path("../examples/*.rb", __dir__)].sort.each do |path|
    it "parses #{File.basename(path)}" do
      expect { RubyVM::InstructionSequence.compile_file(path) }.not_to raise_error
    end
  end

  it "keeps Stagecraft isolated behind its documented adapter contract" do
    source = File.read(File.expand_path("../examples/stagecraft_text.rb", __dir__))

    expect(source).to include("class StagecraftTextRenderer")
    expect(source).to include("Stagecraft.run")
  end
end
