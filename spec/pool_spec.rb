# frozen_string_literal: true

RSpec.describe FreeType::Pool do
  let(:font_path) { File.expand_path("fixtures/ABeeZee-Regular.ttf", __dir__) }

  it "caches faces within a thread and isolates native libraries between threads" do
    pool = described_class.new
    main_face = pool.face(font_path)
    expect(pool.face(font_path)).to equal(main_face)

    worker_addresses = Thread.new do
      [pool.library.pointer.address, pool.face(font_path).pointer.address]
    end.value

    expect(worker_addresses.first).not_to eq(pool.library.pointer.address)
    expect(worker_addresses.last).not_to eq(main_face.pointer.address)
  ensure
    pool&.close
  end
end
