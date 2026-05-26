# Output subsystem — Crystal port of worktrunk/src/output/
#
# Centralized output routing for stdout (data) and stderr (status).
# Manages global verbosity level and provides consistent output helpers.
#
# stdout: primary data output (table data, JSON, statusline)
# stderr: status messages (progress, success, errors, hints, warnings)

module WorkTrees
  module Output
    # Global verbosity: 0=normal, 1=verbose(-v), 2=debug(-vv)
    @@verbosity : Int32 = 0

    def self.verbosity : Int32
      @@verbosity
    end

    def self.verbosity=(value : Int32) : Int32
      @@verbosity = value
    end

    def self.verbose? : Bool
      @@verbosity >= 1
    end

    def self.debug? : Bool
      @@verbosity >= 2
    end

    # Initialize verbosity from CLI flags or WORKTREES_VERBOSE env var.
    def self.init_from_flags(args : Array(String)) : Nil
      if args.any? { |a| a == "-vv" }
        @@verbosity = 2
      elsif args.any? { |a| a == "-v" }
        @@verbosity = 1
      elsif v = ENV["WORKTREES_VERBOSE"]?
        @@verbosity = v.to_i? || 0
      end
    end

    # Write a status message to stderr (for progress, warnings, errors).
    def self.status(message : String, io : IO = STDERR) : Nil
      io.puts message
    end

    # Write data output to stdout (table data, JSON, statusline).
    def self.data(message : String, io : IO = STDOUT) : Nil
      io.puts message
    end

    # Format command output: gutter-formatted when verbose, plain otherwise.
    def self.command_output(command : String, output : String) : String
      if verbose?
        Styling.format_with_gutter("#{command}\n#{output}", Styling.terminal_width)
      else
        output
      end
    end
  end
end
