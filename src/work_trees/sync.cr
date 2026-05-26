# Synchronization primitives for work_trees.
#
# Ported from vendor/worktrunk/src/sync.rs
#
# A counting semaphore for limiting concurrency of heavy operations
# (e.g., git mmap-intensive commands).

module WorkTrees
  module Sync
    # A counting semaphore for limiting concurrency.
    #
    # Uses Crystal's Channel as a counting semaphore: each acquire sends
    # a message into the channel (blocking when full), each release receives
    # one. The block form automatically releases the permit.
    class Semaphore
      def initialize(@permits : Int32)
        # Pre-fill the channel with permits so first N acquires are non-blocking.
        @channel = Channel(Nil).new(@permits)
        @permits.times { @channel.send(nil) }
      end

      # Acquire a permit, run the block, then release the permit.
      # Blocks if no permits are available.
      def acquire(& : -> T) : T forall T
        @channel.receive # take a permit (blocks if none available)
        begin
          yield
        ensure
          @channel.send(nil) # return the permit
        end
      end
    end
  end
end
