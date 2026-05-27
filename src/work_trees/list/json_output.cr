# JSON output types — Crystal port of vendor/worktrunk/src/commands/list/json_output.rs
#
# Structured JSON output format for wt list --format=json.
# Uses JSON::Serializable for type-safe serialization matching vendor field names.

require "json"

module WorkTrees
  module List
    module JsonOutput
      struct JsonDiff
        include JSON::Serializable

        property added : Int32
        property deleted : Int32

        def initialize(@added : Int32 = 0, @deleted : Int32 = 0)
        end
      end

      struct JsonCommit
        include JSON::Serializable

        property sha : String
        property short_sha : String
        property message : String
        property timestamp : Int64

        def initialize(@sha : String, @short_sha : String, @message : String, @timestamp : Int64)
        end
      end

      struct JsonWorkingTree
        include JSON::Serializable

        property? staged : Bool = false
        property? modified : Bool = false
        property? untracked : Bool = false
        property? renamed : Bool = false
        property? deleted : Bool = false
        property diff : JsonDiff?

        def initialize(
          @staged = false,
          @modified = false,
          @untracked = false,
          @renamed = false,
          @deleted = false,
          @diff = nil,
        )
        end
      end

      struct JsonMain
        include JSON::Serializable

        property ahead : Int32 = 0
        property behind : Int32 = 0
        property diff : JsonDiff?
      end

      struct JsonRemote
        include JSON::Serializable

        property name : String
        property branch : String
        property ahead : Int32 = 0
        property behind : Int32 = 0

        def initialize(@name : String, @branch : String, @ahead = 0, @behind = 0)
        end
      end

      struct JsonWorktree
        include JSON::Serializable

        property state : String?
        property reason : String?
        property? detached : Bool = false
      end

      struct JsonCi
        include JSON::Serializable

        property status : String
        property source : String
        property? stale : Bool = false
        property url : String?

        def initialize(@status : String, @source : String, @stale = false, @url = nil)
        end
      end

      struct JsonItem
        include JSON::Serializable

        property branch : String?
        property path : String?
        property kind : String
        property commit : JsonCommit

        @[JSON::Field(key: "working_tree")]
        property working_tree : JsonWorkingTree?

        @[JSON::Field(key: "main_state")]
        property main_state : String?

        @[JSON::Field(key: "integration_reason")]
        property integration_reason : String?

        @[JSON::Field(key: "operation_state")]
        property operation_state : String?

        property main : JsonMain?
        property remote : JsonRemote?
        property worktree : JsonWorktree?

        @[JSON::Field(key: "is_main")]
        property? is_main : Bool = false

        @[JSON::Field(key: "is_current")]
        property? is_current : Bool = false

        @[JSON::Field(key: "is_previous")]
        property? is_previous : Bool = false

        property ci : JsonCi?
        property url : String?

        @[JSON::Field(key: "url_active")]
        property url_active : Bool?

        property summary : String?
        property statusline : String?
        property symbols : String?

        def initialize(
          @commit : JsonCommit,
          @kind : String = "worktree",
          @branch : String? = nil,
          @path : String? = nil,
          @working_tree : JsonWorkingTree? = nil,
          @main_state : String? = nil,
          @integration_reason : String? = nil,
          @operation_state : String? = nil,
          @main : JsonMain? = nil,
          @remote : JsonRemote? = nil,
          @worktree : JsonWorktree? = nil,
          @is_main : Bool = false,
          @is_current : Bool = false,
          @is_previous : Bool = false,
          @ci : JsonCi? = nil,
          @url : String? = nil,
          @url_active : Bool? = nil,
          @summary : String? = nil,
          @statusline : String? = nil,
          @symbols : String? = nil,
        )
        end
      end
    end
  end
end
