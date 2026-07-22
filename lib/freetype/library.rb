# frozen_string_literal: true

require "set"

module FreeType
  class Library
    include Enumerable

    attr_reader :pointer

    def initialize
      output = FFI::MemoryPointer.new(:pointer)
      Native.check!(Native.FT_Init_FreeType(output), "FT_Init_FreeType")
      @pointer = output.read_pointer
      @faces = Set.new
      @state = { pointer: @pointer, faces: [], closed: false }
      ObjectSpace.define_finalizer(self, self.class.finalizer(@state))
    end

    def self.open
      library = new
      return library unless block_given?

      begin
        yield library
      ensure
        library.close
      end
    end

    def self.finalizer(state)
      proc do
        next if state[:closed]

        state[:faces].each do |face_state|
          next if face_state[:closed]

          Native.FT_Done_Face(face_state[:pointer])
          face_state[:closed] = true
        end
        Native.FT_Done_FreeType(state[:pointer])
        state[:closed] = true
      end
    end

    def face(source, face_index: 0)
      ensure_open!
      created = Face.new(self, source, face_index: face_index)
      @faces.add(created)
      @state[:faces] << created.__send__(:native_state)
      return created unless block_given?

      begin
        yield created
      ensure
        created.close
      end
    end

    def each(&block)
      @faces.each(&block)
    end

    def version
      ensure_open!
      values = Array.new(3) { FFI::MemoryPointer.new(:int) }
      Native.FT_Library_Version(pointer, *values)
      values.map(&:read_int).freeze
    end

    def close
      return if closed?

      @faces.to_a.each(&:close)
      Native.check!(Native.FT_Done_FreeType(pointer), "FT_Done_FreeType")
      @state[:closed] = true
      nil
    end

    def closed?
      @state[:closed]
    end

    private

    def unregister(face)
      @faces.delete(face)
      @state[:faces].delete(face.__send__(:native_state))
    end

    def ensure_open!
      raise ClosedError, "library is closed" if closed?
    end
  end
end
