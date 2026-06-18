module CourseTransfer
  # Runs independent file operations on a bounded set of worker threads.
  class FilePool
    DEFAULT_SIZE = Integer(
      ENV.fetch("AUTOLAB_COURSE_TRANSFER_FILE_WORKERS", "8")
    ).clamp(1, 32)

    # Opens a pool and waits for every submitted operation before returning.
    #
    # @param size [Integer] number of concurrent file operations
    # @yieldparam pool [CourseTransfer::FilePool]
    # @return [Object] value returned by the block
    def self.open(size: DEFAULT_SIZE)
      pool = new(size:)
      result = error = finish_error = nil

      begin
        result = yield pool
      rescue StandardError => e
        error = e
      ensure
        begin
          pool.finish
        rescue StandardError => e
          finish_error = e
        end
      end

      raise error if error
      raise finish_error if finish_error

      result
    end

    # @param size [Integer] number of concurrent file operations
    def initialize(size: DEFAULT_SIZE)
      @queue = SizedQueue.new(size * 2)
      @errors = Queue.new
      @finished = false
      @threads = Array.new(size) { start_worker }
    end

    # @param arguments [Array<Object>] values passed to the operation
    # @yield file operation
    # @return [void]
    def post(*arguments, &operation)
      raise ArgumentError, "file operation is required" unless operation
      raise IOError, "file pool is closed" if @finished

      @queue << [operation, arguments]
    end

    # Waits for all queued work and raises the first worker error.
    #
    # @return [void]
    def finish
      return if @finished

      @finished = true
      @threads.length.times { @queue << nil }
      @threads.each(&:join)
      raise @errors.pop unless @errors.empty?
    end

  private

    def start_worker
      Thread.new do
        while (job = @queue.pop)
          begin
            operation, arguments = job
            operation.call(*arguments)
          rescue StandardError => e
            @errors << e
          end
        end
      end
    end
  end
end
