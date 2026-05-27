# Shell wrapper template generation.
#
# Ported from vendor/worktrunk/src/shell/mod.rs and templates/*.sh
#
# Divergence: upstream uses askama (compile-time) for shell templates.
# Crystal uses Template.expand (runtime) — same engine as config templates.
# This is the ECR divergence in practice.

require "../template/expansion"

module WorkTrees
  module Shell
    # Template for bash shell wrapper.
    BASH_TEMPLATE = <<-BASH
    # wktrees shell integration for {{ shell_name }}

    if command -v {{ cmd }} >/dev/null 2>&1; then
        {{ cmd }}() {
            local args=()

            for arg in "$@"; do
                if [[ "$arg" == "--source" ]]; then
                    local use_source=true
                else
                    args+=("$arg")
                fi
            done

            if [[ -n "${COMPLETE:-}" ]]; then
                command {{ cmd }} "${args[@]}"
                return
            fi

            local cd_file exec_file exit_code=0
            cd_file="$(mktemp)"
            exec_file="$(mktemp)"

            WORKTRUNK_DIRECTIVE_CD_FILE="$cd_file" WORKTRUNK_DIRECTIVE_EXEC_FILE="$exec_file" \
                command {{ cmd }} "${args[@]}" || exit_code=$?

            if [[ -s "$cd_file" ]]; then
                builtin cd -- "$(<"$cd_file")"
                local cd_exit=$?
                if [[ $exit_code -eq 0 ]]; then
                    exit_code=$cd_exit
                fi
            fi

            if [[ -s "$exec_file" ]]; then
                source "$exec_file"
            fi

            rm -f "$cd_file" "$exec_file"
            return "$exit_code"
        }
    fi
    BASH

    # Template for zsh shell wrapper.
    ZSH_TEMPLATE = <<-ZSH
    # wktrees shell integration for {{ shell_name }}

    if (( ${+commands[{{ cmd }}]} )); then
        {{ cmd }}() {
            local args=() use_source=0

            for arg in "$@"; do
                if [[ "$arg" == "--source" ]]; then
                    use_source=1
                else
                    args+=("$arg")
                fi
            done

            if [[ -n "${COMPLETE:-}" ]]; then
                command {{ cmd }} "${args[@]}"
                return
            fi

            local cd_file exec_file exit_code=0
            cd_file="$(mktemp)"
            exec_file="$(mktemp)"

            WORKTRUNK_DIRECTIVE_CD_FILE="$cd_file" WORKTRUNK_DIRECTIVE_EXEC_FILE="$exec_file" \
                command {{ cmd }} "${args[@]}" || exit_code=$?

            if [[ -s "$cd_file" ]]; then
                cd -- "$(<"$cd_file")"
            fi

            if [[ -s "$exec_file" ]]; then
                source "$exec_file"
            fi

            rm -f "$cd_file" "$exec_file"
            return "$exit_code"
        }
    fi
    ZSH

    # Template for fish shell wrapper.
    FISH_TEMPLATE = <<-FISH
    # wktrees shell integration for {{ shell_name }}

    if command -q {{ cmd }}
        function {{ cmd }}
            set -l args
            set -l use_source 0

            for arg in $argv
                if test "$arg" = "--source"
                    set use_source 1
                else
                    set -a args $arg
                end
            end

            if set -q COMPLETE
                command {{ cmd }} $args
                return
            end

            set -l cd_file (mktemp)
            set -l exec_file (mktemp)
            set -l exit_code 0

            env WORKTRUNK_DIRECTIVE_CD_FILE="$cd_file" WORKTRUNK_DIRECTIVE_EXEC_FILE="$exec_file" \
                command {{ cmd }} $args; or set exit_code $status

            if test -s "$cd_file"
                builtin cd (cat "$cd_file")
            end

            if test -s "$exec_file"
                source "$exec_file"
            end

            rm -f "$cd_file" "$exec_file"
            return $exit_code
        end
    end
    FISH

    # Template for nushell wrapper.
    NU_TEMPLATE = <<-NU
    # wktrees shell integration for {{ shell_name }}

    export def --env --wrapped {{ cmd }} [...args] {
        let cd_file = (mktemp --tmpdir)
        let exec_file = (mktemp --tmpdir)

        let exit_code = (try {
            with-env { WORKTRUNK_DIRECTIVE_CD_FILE: $cd_file, WORKTRUNK_DIRECTIVE_EXEC_FILE: $exec_file } {
                ^{{ cmd }} ...$args
            }
            0
        } catch {
            $env.LAST_EXIT_CODE
        })

        if ($cd_file | path exists) and (open $cd_file --raw | str trim | is-not-empty) {
            cd (open $cd_file --raw | str trim)
        }

        if ($exec_file | path exists) and (open $exec_file --raw | str trim | is-not-empty) {
            ^sh -c (open $exec_file --raw)
        }

        rm -f $cd_file $exec_file

        if $exit_code != 0 {
            ^sh -c $"exit ($exit_code)"
        }
    }
    NU

    # Template for powershell wrapper.
    PS_TEMPLATE = <<-PS
    # wktrees shell integration for {{ shell_name }}

    function Invoke-{{ cmd }} {
        $cdFile = New-TemporaryFile
        $execFile = New-TemporaryFile

        $env:WORKTRUNK_DIRECTIVE_CD_FILE = $cdFile.FullName
        $env:WORKTRUNK_DIRECTIVE_EXEC_FILE = $execFile.FullName

        & {{ cmd }} @args
        $exitCode = $LASTEXITCODE

        if ((Get-Content $cdFile.FullName -Raw).Trim() -ne "") {
            Set-Location (Get-Content $cdFile.FullName -Raw).Trim()
        }

        if ((Get-Content $execFile.FullName -Raw).Trim() -ne "") {
            & sh -c (Get-Content $execFile.FullName -Raw)
        }

        Remove-Item $cdFile, $execFile -Force
        exit $exitCode
    }

    Set-Alias -Name {{ cmd }} -Value Invoke-{{ cmd }}
    PS

    # Generate a shell wrapper for the given shell type and command name.
    def self.generate(shell : Symbol, cmd : String = "wktrees") : String
      template = case shell
                 when :bash            then BASH_TEMPLATE
                 when :zsh             then ZSH_TEMPLATE
                 when :fish            then FISH_TEMPLATE
                 when :nu, :nushell    then NU_TEMPLATE
                 when :ps, :powershell then PS_TEMPLATE
                 else                       raise "Unsupported shell: #{shell}"
                 end
      vars = {"shell_name" => shell.to_s, "cmd" => cmd}
      Template.expand(template, vars)
    end
  end
end
