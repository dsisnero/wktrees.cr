# Command tracing — Crystal port of worktrunk/src/trace/emit.rs
#
# Emits structured [wt-trace] records for subprocess commands and
# in-process spans. Records are single-line key=value text logged
# to STDERR when verbose mode is active (WORKTREES_VERBOSE=2).
#
# Format:
#   [wt-trace] ts=1234567 tid=3 context=feature cmd="git status" dur_us=12300 ok=true
#   [wt-trace] ts=1234567 tid=3 span="config_load" dur_us=8200
#   [wt-trace] ts=1234567 tid=3 event="Showed skeleton"

module WorkTrees
  module Trace
    # Monotonic epoch for trace timestamps — all ts fields are
    # microseconds since this point.
    EPOCH = Time.instant

    def self.now_us : UInt64
      (Time.instant - EPOCH).total_microseconds.to_u64
    end

    # Whether trace logging is enabled (WORKTREES_VERBOSE=2 or -vv).
    def self.enabled? : Bool
      Output.debug?
    end

    # Log a trace record to STDERR if tracing is enabled.
    def self.emit(record : String) : Nil
      STDERR.puts record if enabled?
    end

    # Format a [wt-trace] record for a completed or failed subprocess command.
    #
    # context: optional worktree/branch name the command is scoped to
    # ok: true when exit code is 0, false otherwise
    def self.format_command(
      program : String,
      args : String,
      ts : UInt64,
      tid : UInt64,
      dur_us : UInt64,
      ok : Bool,
      context : String? = nil,
    ) : String
      if ctx = context
        %([wt-trace] ts=#{ts} tid=#{tid} context=#{ctx} cmd="#{program} #{args}" dur_us=#{dur_us} ok=#{ok})
      else
        %([wt-trace] ts=#{ts} tid=#{tid} cmd="#{program} #{args}" dur_us=#{dur_us} ok=#{ok})
      end
    end

    # Format a [wt-trace] record for a completed in-process span.
    def self.format_span(name : String, ts : UInt64, tid : UInt64, dur_us : UInt64) : String
      %([wt-trace] ts=#{ts} tid=#{tid} span="#{name}" dur_us=#{dur_us})
    end

    # Format a [wt-trace] instant (milestone) event with auto-timestamp.
    def self.format_instant(event : String) : String
      %([wt-trace] ts=#{now_us} tid=#{thread_id} event="#{event}")
    end

    # Format a [wt-trace] record for a command that failed to start.
    def self.format_error(
      program : String,
      args : String,
      ts : UInt64,
      tid : UInt64,
      dur_us : UInt64,
      err : String,
    ) : String
      %([wt-trace] ts=#{ts} tid=#{tid} cmd="#{program} #{args}" dur_us=#{dur_us} ok=false err="#{err}")
    end

    # RAII-like span guard that times its enclosing scope and emits
    # a span record when #done is called. Because Crystal structs lack
    # finalizers, callers must invoke #done explicitly.
    #
    # Usage:
    #   span = Trace::Span.new("config_load")
    #   do_work()
    #   span.done
    class Span
      @name : String
      @start_ts : UInt64
      @start_time : Time

      def initialize(@name : String)
        @start_ts = Trace.now_us
        @start_time = Time.instant
      end

      def done : Nil
        dur = Time.instant - @start_time
        dur_us = dur.total_microseconds.to_u64
        record = Trace.format_span(@name, @start_ts, Trace.thread_id, dur_us)
        Trace.emit(record)
      end
    end

    # Thread-id-ish: returns a small integer derived from the fiber's
    # object_id for disambiguation in traces. Crystal fibers share an
    # OS thread pool but have distinct object_ids.
    def self.thread_id : UInt64
      Fiber.current.object_id.to_u64 & 0xFFFF_u64
    end

    # Time a block and emit a span record on completion.
    # Returns the block's result unchanged.
    #
    # Usage:
    #   result = Trace.span("config_load") { load_config }
    def self.span(name : String, &)
      start_ts = now_us
      start_time = Time.instant
      result = yield
      dur = Time.instant - start_time
      dur_us = dur.total_microseconds.to_u64
      record = format_span(name, start_ts, thread_id, dur_us)
      emit(record)
      result
    end
  end
end
