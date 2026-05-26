require "../spec_helper"
require "../../src/work_trees/sync"

module WorkTrees::Sync
  describe Semaphore do
    it "allows up to permit count concurrent acquires" do
      sem = Semaphore.new(3)
      counter = Atomic(Int32).new(0)
      max_seen = Atomic(Int32).new(0)
      done = Channel(Nil).new(5)

      5.times do
        spawn do
          sem.acquire do
            current = counter.add(1)
            if current > max_seen.get
              max_seen.set(current.to_i32)
            end
            sleep 0.03.seconds
            counter.sub(1)
          end
          done.send(nil)
        end
      end

      5.times { done.receive }

      # Should never have more than 3 concurrent
      max_seen.get.should be <= 3
      # And at least some concurrency happened
      max_seen.get.should be >= 2
    end

    it "runs sequential correctly" do
      sem = Semaphore.new(1)
      results = [] of Int32
      mutex = Mutex.new
      done = Channel(Nil).new(3)

      3.times do |i|
        spawn do
          sem.acquire do
            mutex.synchronize { results << i }
            sleep 0.01.seconds
          end
          done.send(nil)
        end
      end

      3.times { done.receive }
      results.size.should eq(3)
    end
  end
end
