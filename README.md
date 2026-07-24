# claude-science-nix

Run [claude-science](https://claude.com/product/claude-science) on NixOS.

Its conda connectors and `bwrap` agent sandbox expect an FHS layout NixOS
does not have, so the daemon starts but every bundled connector fails.
This flake wraps it in `buildFHSEnv`.

The binary is not vendored. It downloads from Anthropic on first use and
self-updates, so nothing here is version-pinned, and there is no hash to
verify it against.

## Run it

```sh
nix run github:pleahmacaka/claude-science-nix -- serve
```

```sh
# put `claude-science` on PATH for this shell
nix shell github:pleahmacaka/claude-science-nix

# bash inside the FHS layout
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

As a home-manager module inside a NixOS flake, pass `inputs` down:

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
| `packages.sandbox` | bash inside the FHS layout |
| `apps.default` | `nix run` target |

## Notes

- x86_64-linux only, no upstream arm64 build.
- Binary goes to `~/.local/bin/claude-science`, data to
  `~/.claude-science`. Expect several GB once the conda environments build.
- WSL: the daemon cannot launch a Windows browser, so open the printed
  link yourself or run `claude-science url` for a fresh one.
