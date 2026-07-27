{
  # claude-science ships MCP connectors that build conda envs via shell
  # scripts calling bare `mkdir`/`sleep` and expecting /usr/bin + an FHS
  # dynamic linker; it also shells out to `bwrap` for its agent sandbox.
  # NixOS has none of that, so buildFHSEnv fakes the layout.
  #
  #   nix run . -- serve
  #   nix shell           # puts `claude-science` on PATH
  #   nix run .#sandbox   # bash inside the FHS layout
  description = "Run claude-science (Claude on your data, locally) on NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # Anthropic publishes a linux-x64 build only.
      systems = [ "x86_64-linux" ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s} s);

      baseMeta = {
        description = "claude-science, wrapped in an FHS sandbox so it runs on NixOS";
        homepage = "https://github.com/pleahmacaka/claude-science-nix";
        license = nixpkgs.lib.licenses.mit;
        platforms = systems;
      };

      mkFhs = pkgs: args:
        let
          # claude-science's inner bwrap sandbox re-binds this env's /etc/ssl and
          # strips env vars, so the certs must be real files at the standard path,
          # not NixOS /etc/static symlinks (they dangle inside the inner sandbox).
          etcSsl = pkgs.runCommand "fhs-etc-ssl" { } ''
            mkdir -p $out/certs
            cp ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/certs/ca-certificates.crt
            ln -s ca-certificates.crt $out/certs/ca-bundle.crt
            cp ${pkgs.openssl.out}/etc/ssl/openssl.cnf $out/openssl.cnf
          '';
        in
        pkgs.buildFHSEnv ({
          targetPkgs = p: with p; [
            coreutils bash zsh which
            gnused gnugrep gawk findutils
            gnutar gzip bzip2 xz zstd
            curl wget cacert git
            glibc zlib openssl stdenv.cc.cc.lib
            procps
            bubblewrap socat
            python3
          ];
          extraBwrapArgs = [ "--ro-bind" "${etcSsl}" "/etc/ssl" ];
          profile = ''
            export PATH="$HOME/.local/bin:$PATH"
            export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
            export NIX_SSL_CERT_FILE=$SSL_CERT_FILE
            export REQUESTS_CA_BUNDLE=$SSL_CERT_FILE
            export CURL_CA_BUNDLE=$SSL_CERT_FILE
            export CONDA_SSL_VERIFY=$SSL_CERT_FILE
          '';
        } // args);
    in
    {
      packages = eachSystem (pkgs: _:
        let
          sandbox = mkFhs pkgs {
            name = "claude-science-fhs";
            runScript = "bash";
            meta = baseMeta // {
              description = "Bash shell inside the claude-science FHS sandbox";
              mainProgram = "claude-science-fhs";
            };
          };
          claude-science = mkFhs pkgs {
            name = "claude-science";
            meta = baseMeta // { mainProgram = "claude-science"; };
            # The binary is never vendored into the store: it is fetched from
            # Anthropic on first use and keeps itself current via
            # `claude-science update`, so the flake never pins a version.
            runScript = pkgs.writeShellScript "claude-science-entry" ''
              set -eu
              # Must stay off PATH, or the raw binary shadows this wrapper.
              bin="''${CLAUDE_SCIENCE_BIN:-''${HOME:?HOME is unset; set CLAUDE_SCIENCE_BIN instead}/.local/share/claude-science/bin/claude-science}"
              if [ ! -x "$bin" ]; then
                echo "Downloading claude-science to $bin..." >&2
                mkdir -p "$(dirname "$bin")"
                # No hash to verify against by design, so TLS is the only
                # control: refuse a redirect that downgrades to plaintext.
                curl -fL --proto '=https' --proto-redir '=https' --progress-bar \
                  https://downloads.claude.ai/claude-science/latest/linux-x64 \
                  -o "$bin.partial"
                chmod +x "$bin.partial"
                mv "$bin.partial" "$bin"
              fi
              exec "$bin" "$@"
            '';
          };
        in
        {
          inherit sandbox;
          default = claude-science;
        });

      apps = eachSystem (_: system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/claude-science";
        };
      });
    };
}
