# claude-science-nix

[claude-science](https://claude.com/product/claude-science) packaged for NixOS.

Its conda connectors and `bwrap` agent sandbox need an FHS layout, so this
runs it under `buildFHSEnv`. The binary is not vendored: it is fetched from
Anthropic on first run and self-updates, so no version or hash is pinned.

```sh
nix run github:pleahmacaka/claude-science-nix -- serve
```

## Flake input

```nix
inputs.claude-science.url = "github:pleahmacaka/claude-science-nix";
inputs.claude-science.inputs.nixpkgs.follows = "nixpkgs";
```

```nix
# NixOS
environment.systemPackages = [ inputs.claude-science.packages.x86_64-linux.default ];

# home-manager
home.packages = [ inputs.claude-science.packages.x86_64-linux.default ];
```

## Outputs

- `packages.default` - the `claude-science` launcher
- `packages.sandbox` - bash inside the FHS layout
- `apps.default` - `nix run` target

x86_64-linux only. Data and conda environments land in `~/.claude-science`,
several GB after the first run.
