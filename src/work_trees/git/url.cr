# Git remote URL parsing — Crystal port of worktrunk/src/git/url.rs
#
# Parses git remote URLs into structured components (host, owner, repo).
# Supports HTTPS, SSH, and git@ URL formats with forge detection.

module WorkTrees
  module Git
    struct GitRemoteUrl
      getter host : String
      getter owner : String
      getter repo : String

      def initialize(@host : String, @owner : String, @repo : String)
      end

      # Parse a git remote URL into structured components.
      #
      # Supported formats:
      # - https://<host>/<owner>/<repo>.git
      # - http://<host>/<owner>/<repo>.git
      # - git://<host>/<owner>/<repo>.git
      # - git@<host>:<owner>/<repo>.git
      # - ssh://[git@]<host>[:<port>]/<owner>/<repo>.git
      #
      # Returns nil for malformed URLs or unsupported formats.
      def self.parse(url : String) : GitRemoteUrl?
        url = url.strip
        return nil if url.empty?

        host, path = extract_host_and_path(url)
        return nil unless host && path

        build_from_parts(host, path)
      end

      # Extract host and path from a URL string via protocol or git@ match.
      private def self.extract_host_and_path(url : String) : {String?, String?}
        case
        when url.starts_with?("https://") then parse_protocol(url, "https://")
        when url.starts_with?("http://")  then parse_protocol(url, "http://")
        when url.starts_with?("git://")   then parse_protocol(url, "git://")
        when url.starts_with?("ssh://")   then parse_protocol(url, "ssh://")
        when url.starts_with?("git@")     then parse_git_at(url)
        else                                   {nil, nil}
        end
      end

      # Build a GitRemoteUrl from parsed host and path.
      private def self.build_from_parts(host : String, path : String) : GitRemoteUrl?
        parts = path.split('/').reject(&.empty?)
        return nil if parts.size < 2

        repo_part = parts.last
        repo = repo_part.ends_with?(".git") ? repo_part[0...-4] : repo_part
        owner = parts[0...-1].join('/')

        return nil if owner.empty? || repo.empty?

        port_pos = host.index(':')
        host = host[0...port_pos] if port_pos

        new(host, owner, repo)
      end

      # Parse protocol-prefixed URL (https://, http://, git://, ssh://).
      private def self.parse_protocol(url : String, prefix : String) : {String?, String?}
        rest = url[prefix.size..]
        # Strip git@ from ssh://git@host/...
        rest = rest[4..] if prefix == "ssh://" && rest.starts_with?("git@")
        pos = rest.index('/')
        return {nil, nil} unless pos
        host = rest[0...pos]
        # Strip port from host
        host = host.split(':')[0] if host.includes?(':')
        path = rest[(pos + 1)..]
        {host, path}
      end

      # Parse git@ URL format: git@github.com:user/repo.git
      private def self.parse_git_at(url : String) : {String?, String?}
        rest = url[4..] # strip "git@"
        pos = rest.index(':')
        return {nil, nil} unless pos
        host = rest[0...pos]
        path = rest[(pos + 1)..]
        {host, path}
      end

      # -- Forge detection ----------------------------------------------------

      def github? : Bool
        @host.includes?("github")
      end

      def gitlab? : Bool
        @host.includes?("gitlab")
      end

      def gitea? : Bool
        @host.includes?("gitea")
      end

      def azure? : Bool
        @host == "dev.azure.com" || @host.includes?("visualstudio.com") || @host.ends_with?(".dev.azure.com")
      end

      # -- Identifiers --------------------------------------------------------

      def project_identifier : String
        "#{@host}/#{@owner}/#{@repo}"
      end

      # Shorthand to extract (owner, repo) from a URL without creating
      # the full GitRemoteUrl struct.
      def self.parse_owner_repo(url : String) : {String, String}?
        u = parse(url)
        u ? {u.owner, u.repo} : nil
      end
    end
  end
end
