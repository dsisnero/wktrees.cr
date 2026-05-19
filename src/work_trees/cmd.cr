# Port of the shell_exec::Cmd builder from vendor/worktrunk/src/shell_exec.rs
#
# Provides a unified interface for executing external commands (git, gh, etc.)
# with structured logging and consistent error handling.
#
# All external commands go through this builder — never use `Process.run` directly.

require "log"

module WorkTrees
  # Builder for executing external commands.
  #
  # ```
  # output = WorkTrees::Cmd.new("git")
  #   .args(["status", "--porcelain"])
  #   .current_dir(worktree_path)
  #   .context("feature-auth")
  #   .run
  # ```
  class Cmd
    @program : String
    @args : Array(String)
    @current_dir : String?
    @context : String?
    @stdin_data : Bytes?

    def initialize(@program : String)
      @args = [] of String
      @current_dir = nil
      @context = nil
      @stdin_data = nil
    end

    # Add a single argument.
    def arg(arg : String) : self
      @args << arg
      self
    end

    # Add multiple arguments.
    def args(args : Enumerable(String)) : self
      @args.concat(args)
      self
    end

    # Set the working directory for the command.
    def current_dir(dir : String) : self
      @current_dir = dir
      self
    end

    # Set a logging context label (typically worktree name for git commands).
    def context(ctx : String) : self
      @context = ctx
      self
    end

    # Set data to pipe to the command's stdin.
    def stdin_bytes(data : Bytes) : self
      @stdin_data = data
      self
    end

    # Set stdin from a string.
    def stdin_data(data : String) : self
      @stdin_data = data.to_slice
      self
    end

    # Execute the command and return the result.
    #
    # Returns a `CmdResult` with status, stdout, and stderr.
    # Raises on failure to start the process.
    def run : CmdResult
      cmd_str = command_string
      log_start(cmd_str)

      stdout = IO::Memory.new
      stderr = IO::Memory.new
      stdin = if data = @stdin_data
                IO::Memory.new(data)
              else
                Process::Redirect::Close
              end

      process = Process.new(
        @program,
        @args,
        env: nil,
        chdir: @current_dir,
        input: stdin,
        output: stdout,
        error: stderr,
        shell: false
      )

      status = process.wait
      result = CmdResult.new(
        status: status,
        stdout: stdout.to_s,
        stderr: stderr.to_s
      )

      log_result(cmd_str, result)
      result
    rescue ex : IO::Error
      log_error(command_string, ex)
      raise ex
    end

    # Execute and raise if the command fails.
    #
    # Returns the CmdResult on success.
    # Raises `CmdError` if the process exits with non-zero status.
    def run! : CmdResult
      result = run
      unless result.success?
        raise CmdError.new(
          program: @program,
          args: @args,
          stderr: result.stderr,
          stdout: result.stdout,
          exit_code: result.exit_code
        )
      end
      result
    end

    def command_string : String
      if @args.empty?
        @program
      else
        "#{@program} #{@args.join(" ")}"
      end
    end

    private def log_start(cmd_str : String)
      case @context
      when String
        Log.debug { "$ #{cmd_str} [#{@context}]" }
      else
        Log.debug { "$ #{cmd_str}" }
      end
    end

    private def log_result(cmd_str : String, result : CmdResult)
      if result.success?
        Log.debug { "$ #{cmd_str} — ok (#{result.exit_code})" }
      else
        Log.debug { "$ #{cmd_str} — FAILED (#{result.exit_code}): #{result.stderr.lines.first?}" }
      end
    end

    private def log_error(cmd_str : String, ex : Exception)
      Log.error { "$ #{cmd_str} — ERROR: #{ex.message}" }
    end
  end

  # Result of executing a command.
  struct CmdResult
    getter status : Process::Status
    getter stdout : String
    getter stderr : String

    def initialize(@status : Process::Status, @stdout : String, @stderr : String)
    end

    def success? : Bool
      @status.success?
    end

    def exit_code : Int32
      @status.exit_code
    end
  end

  # Error raised when a command fails.
  class CmdError < Exception
    getter program : String
    getter args : Array(String)
    getter stderr : String
    getter stdout : String
    getter exit_code : Int32

    def initialize(@program : String, @args : Array(String), @stderr : String, @stdout : String, @exit_code : Int32)
      super("#{@program} #{@args.join(" ")} failed with exit code #{@exit_code}: #{@stderr}")
    end
  end
end
