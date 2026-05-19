# Port of the codename filter from vendor/worktrunk/src/config/expansion.rs:506
#
# Deterministic friendly-name generator. Two-word names (adjective-noun)
# by default, configurable up to CODENAME_MAX_WORDS.
#
# Uses SHA-256 for deterministic, architecture-independent hashing (same
# as the Rust upstream which uses sha2::Sha256 to avoid usize differences
# between 32-bit and 64-bit builds).
#
# Wordlists are embedded at compile time from:
#   adjectives.txt — 1198 adjectives (petname medium)
#   nouns.txt      — 1052 nouns (petname medium)
#
# Petri dish: ~1.26M codename(2) combinations, ~1.5B for codename(3).

require "openssl"

module WorkTrees
  module Template
    CODENAME_MAX_WORDS = 8

    # Embedded wordlists from petname v3.0.0 (medium).
    ADJECTIVES = {{ read_file("#{__DIR__}/adjectives.txt").lines.map(&.strip).reject(&.empty?) }}
    NOUNS      = {{ read_file("#{__DIR__}/nouns.txt").lines.map(&.strip).reject(&.empty?) }}

    # Generate a deterministic codename from a string.
    #
    # Uses SHA-256 to produce stable output across platforms and architectures.
    # Adjectives are picked first (words - 1), then a noun. Duplicate words
    # in the same codename are avoided by incrementing a salt and re-hashing.
    #
    # ```
    # WorkTrees::Template.codename("feature-auth")    # => "malleable-opah"
    # WorkTrees::Template.codename("feature-auth", 3) # => "abiding-above-aardvark"
    # ```
    def self.codename(input : String, words : Int32 = 2) : String
      raise ArgumentError.new("codename word count must be between 1 and #{CODENAME_MAX_WORDS}") if words < 1 || words > CODENAME_MAX_WORDS

      adjective_count = {words - 1, 0}.max
      parts = [] of String

      adjective_count.times do |position|
        word = pick_word(input, position, "adjective", ADJECTIVES, parts)
        parts << word
      end

      noun = pick_word(input, adjective_count, "noun", NOUNS, parts)
      parts << noun
      parts.join('-')
    end

    # Pick a deterministic word from a pool, avoiding duplicates within the same codename.
    private def self.pick_word(input : String, position : Int32, pool_name : String, pool : Array(String), existing : Array(String)) : String
      salt = 0
      loop do
        index = codename_index(input, position, salt, pool_name, pool.size)
        word = pool[index]
        if !existing.includes?(word) || salt >= pool.size
          return word
        end
        salt += 1
      end
    end

    # Compute a deterministic index into a word pool using SHA-256.
    #
    # Port of `codename_index` (expansion.rs:485).
    # Uses SHA-256 to ensure identical output on 32-bit and 64-bit architectures.
    private def self.codename_index(input : String, position : Int32, salt : Int32, pool_name : String, pool_len : Int32) : Int32
      digest = OpenSSL::Digest.new("SHA256")
      digest.update(input.to_slice)
      digest.update(Bytes[0_u8])
      digest.update(u64_le_bytes(position.to_u64))
      digest.update(u64_le_bytes(salt.to_u64))
      digest.update(pool_name.to_slice)
      hash = digest.final

      # Take first 8 bytes as little-endian u64
      value = 0_u64
      hash[0, 8].each_with_index do |byte, i|
        value |= byte.to_u64 << (i * 8)
      end

      (value % pool_len.to_u64).to_i32
    end

    # Encode a UInt64 as 8 little-endian bytes.
    private def self.u64_le_bytes(value : UInt64) : Bytes
      bytes = Bytes.new(8)
      8.times do |i|
        bytes[i] = (value >> (i * 8)).to_u8
      end
      bytes
    end
  end
end
