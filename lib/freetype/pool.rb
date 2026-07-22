# frozen_string_literal: true

module FreeType
  class Pool
    def initialize
      @mutex = Mutex.new
      @states = {}
      @closed = false
    end

    def self.open
      pool = new
      return pool unless block_given?

      begin
        yield pool
      ensure
        pool.close
      end
    end

    def library
      state.fetch(:library)
    end

    def face(source, face_index: 0)
      current = state
      key = source_key(source, face_index)
      current.fetch(:faces)[key] ||= current.fetch(:library).face(source, face_index: face_index)
    end

    def with_face(source, face_index: 0)
      yield face(source, face_index: face_index)
    end

    def clear
      thread = Thread.current
      current = @mutex.synchronize { @states.delete(thread) }
      current&.fetch(:library)&.close
      nil
    end

    def close
      states = @mutex.synchronize do
        return if @closed

        @closed = true
        previous = @states.values
        @states = {}
        previous
      end
      states.each { |current| current.fetch(:library).close }
      nil
    end

    def closed?
      @mutex.synchronize { @closed }
    end

    private

    def state
      @mutex.synchronize do
        raise ClosedError, "pool is closed" if @closed

        @states[Thread.current] ||= { library: Library.new, faces: {} }
      end
    end

    def source_key(source, face_index)
      path = source.respond_to?(:to_path) ? source.to_path : source
      if path.is_a?(String) && File.file?(path)
        [:path, File.expand_path(path), Integer(face_index)]
      else
        [:memory, source.object_id, Integer(face_index)]
      end
    end
  end
end
