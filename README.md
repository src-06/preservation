# Preservation

Nix tooling to enable declarative management of non-volatile system state.

Inspired and heavily influenced by [impermanence](https://github.com/nix-community/impermanence) but not
meant to be a drop-in replacement.

## Documentation

Docs are available at <https://nix-community.github.io/preservation>
NOTE: The documentation is for the original [preservation](https://github.com/nix-community/preservation) module. This is a fork of that module, so the docs should help you understand the base options. Most options remain the same, except for the removal of `users.<user>`.

## Prerequisites

Requires at least nixos-24.11

## Why?

This aims to provide a declarative state management solution for NixOS systems without resorting to
interpreters to do the heavy lifting. This should enable impermanence-like state management on
an "interpreter-less" NixOS system.

## Simplified User Options

User preservation is configured per `preserveAt` entry using `inUser` instead of nested `users`
submodules. Each `preserveAt` entry is independent and can optionally target a single user:

```nix
preservation = {
  enable = true;

  preserveAt = {
    "/state/system" = { # System-level persistent data
      directories = [ "/var/log" ];
      files = [ { file = "/etc/machine-id"; inInitrd = true; } ];
    };
    "/state/usercache" = { # Persistent cache data, safe to remove when storage is full
      inUser = "alice";
      directories = [ ".local/share/fish" ".local/share/nvim" ];
    };
    "/state/userdata" = { # Important data to persist in separate directories
      inUser = "alice";
      directories = [ "Documents" "Projects" ];
    };
  };
};
```

### Why no per-user nesting?

Ephemeral system setups don't really have per-user profiles. System-level state is managed
through NixOS `specialisation`, which allows having multiple OS configurations on one machine
selectable via the bootloader menu. User data preservation is therefore a flat, per-path
configuration rather than a nested per-user structure.

Related:
- <https://github.com/NixOS/nixpkgs/issues/265640>
- <https://github.com/nix-community/projects/blob/main/proposals/nixpkgs-security-phase2.md#boot-chain-security>

## License

This project is released under the terms of the MIT License. See [LICENSE](./LICENSE).
