# Invocation utilities — Crystal port of vendor/worktrunk/src/invocation.rs
#
# Understands how the binary was invoked to determine binary name,
# whether running as git subcommand, and whether shell integration applies.

module WorkTrees
  module Invocation
    # Get the binary name from PROGRAM_NAME, falling back to "work_trees".
    def self.binary_name : String
      binary_name_from(PROGRAM_NAME)
    end

    # Extract binary name from an argv[0] string.
    def self.binary_name_from(argv0 : String) : String
      name = File.basename(argv0)
      # Strip .exe on Windows
      name = name.rchop(".exe") if name.ends_with?(".exe")
      name
    end

    # Check if running as a git subcommand (via GIT_EXEC_PATH).
    def self.git_subcommand? : Bool
      ENV.has_key?("GIT_EXEC_PATH")
    end

    # Get the invocation path (how the binary was called).
    # Normalizes backslashes to forward slashes.
    def self.invocation_path : String
      invocation_path_from(PROGRAM_NAME)
    end

    def self.invocation_path_from(argv0 : String) : String
      argv0.gsub('\\', '/')
    end

    # Check if invoked with explicit path rather than PATH lookup.
    # Returns true when argv[0] contains / or \.
    def self.was_invoked_with_explicit_path? : Bool
      was_invoked_with_explicit_path?(PROGRAM_NAME)
    end

    def self.was_invoked_with_explicit_path?(argv0 : String) : Bool
      argv0.includes?('/') || argv0.includes?('\\')
    end
  end
end
