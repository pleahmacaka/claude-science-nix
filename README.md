# claude-science-nix

Run [claude-science](https://claude.com/product/claude-science) on NixOS.

It ships MCP connectors that build conda environments (micromamba,
conda-forge) through scripts expecting a normal FHS layout: `/usr/bin`, an
FHS dynamic linker, and real certificate files under `/etc/ssl`. Its agent
sandbox also shells out to `bwrap` and `socat`. Plain NixOS has none of
that, so the daemon starts but every bundled connector fails. This flake
wraps claude-science in a `buildFHSEnv` sandbox that provides the layout,
including a `/etc/ssl/certs/ca-certificates.crt` that stays resolvable
inside claude-science's own nested sandbox.

The binary is not vendored into the Nix store. It is downloaded over HTTPS
from Anthropic (`downloads.claude.ai`) on first use and keeps itself
current through `claude-science update`, so this flake never pins a
version. That also means there is no hash to check it against: always
latest and reproducible-by-hash are mutually exclusive, and this flake
picks always latest. Trust here is the TLS connection to Anthropic, the
same trust the official installer asks for.

## Run it

```sh
nix run github:pleahmacaka/claude-science-nix -- serve
```

That is the whole thing: it downloads claude-science if needed, starts the
daemon, and prints a login link.

Other entry points:

```sh
# put `claude-science` on PATH for this shell
nix shell github:pleahmacaka/claude-science-nix
claude-science serve

# bash inside the FHS layout, to poke at it
nix run github:pleahmacaka/claude-science-nix#sandbox
```

## Install it

### flake.nix (NixOS)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-science.url = "github:pleahmacaka/claude-science-nix";
    claude-science.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, claude-science, ... }: {
    nixosConfigurations.mymachine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          environment.systemPackages = [
            claude-science.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### home-manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    claude-science.url = "github:pleahmacaka/claude-science-nix";
    claude-science.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, claude-science, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        {
          home.username = "me";
          home.homeDirectory = "/home/me";
          home.stateVersion = "25.05";
          home.packages = [
            claude-science.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

As a home-manager module inside an existing NixOS flake, pass the flake
inputs down with `extraSpecialArgs` and the package line is the same:

```nix
home-manager.extraSpecialArgs = { inherit inputs; };
home-manager.users.me = { inputs, ... }: {
  home.packages = [
    inputs.claude-science.packages.x86_64-linux.default
  ];
};
```

### nix profile

```sh
nix profile add github:pleahmacaka/claude-science-nix   # `install` on Nix < 2.30
```

## Outputs

| Output | What it is |
| --- | --- |
| `packages.default` | the `claude-science` launcher |
| `packages.sandbox` | `claude-science-fhs`, a bash shell in the FHS layout |
| `apps.default` | `nix run` target |

## Notes

- x86_64-linux only. Anthropic publishes no arm64 build.
- The binary lands in `~/.local/bin/claude-science`, its own default
  location. `CLAUDE_SCIENCE_BIN` points the first download somewhere
  else, but `claude-science update` still writes to its own default, so
  the two drift apart. Leave it alone unless you have a reason.
- Data lives in `~/.claude-science`, conda environments included. Expect
  several GB after the first run.
- WSL: the daemon cannot launch a Windows browser from inside the
  sandbox. Open the printed `http://127.0.0.1:8000/?nonce=...` link
  yourself, or run `claude-science url` for a fresh one.
