{ config, lib, ... }:

let
  inherit (import ./lib.nix { inherit lib config; })
    mkIntermediateUserDirectories
    concatTwoPaths
    ;

  mountOption = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = ''
          Specify the name of the mount option.
        '';
        example = "bind";
      };
      value = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          Optionally specify a value for the mount option.
        '';
      };
    };
  };

  directoryPath =
    attrs@{ defaultOwner, inUser ? null, ... }:
    {
      options = {
        directory = lib.mkOption {
          type = lib.types.str;
          description = ''
            Specify the path to the directory that should be preserved.
          '';
        };
        how = lib.mkOption {
          type = lib.types.enum [
            "bindmount"
            "symlink"
            "_intermediate"
          ];
          default = "bindmount";
          description = ''
            Specify how this directory should be preserved.

            1. Either a directory is created both on the volatile and on the
            persistent volume, with a bind mount from the former to the
            latter.

            2. Or a symlink is created on the volatile volume, pointing
            to the corresponding location on the persistent volume.

            3. Finally the option `_intermediate` exists to handle directories
            which are supposed to be created on both the volatile and persistent
            volume, but without any preservation of them specifically.
          '';
        };
        user = lib.mkOption {
          type = lib.types.str;
          default = defaultOwner;
          description = ''
            Specify the user that owns the directory.
          '';
        };
        group = lib.mkOption {
          type = lib.types.str;
          default = config.users.users.${defaultOwner}.group;
          defaultText = "config.users.users.\${defaultOwner}.group";
          description = ''
            Specify the group that owns the directory.
          '';
        };
        mode = lib.mkOption {
          type = lib.types.str;
          default = "0755";
          description = ''
            Specify the access mode of the directory.
            See the section `Mode` in {manpage}`tmpfiles.d(5)` for more information.
          '';
        };
        configureParent = lib.mkOption {
          type = lib.types.bool;
          default =
            let
              isUserSymlink = attrs.config.how == "symlink" && attrs.config.user != "root";
              hasInUser = !builtins.isNull inUser;
              notOnTopLevel = !builtins.isNull (builtins.match ".+/.*" attrs.config.directory);
            in
            (isUserSymlink || hasInUser) && notOnTopLevel;
          description = ''
            Specify whether the parent directory of this directory shall be configured with
            custom ownership and permissions.

            By default, missing parent directories are always created with ownership
            `root:root` and mode `0755`, as described in {manpage}`tmpfiles.d(5)`.

            Ownership and mode may be configured through the options
            {option}`parent.user`,
            {option}`parent.group`,
            {option}`parent.mode`.

            Defaults to `true` when {option}`how` is set to `symlink` and
            {option}`user` is not `root`, or when {option}`inUser` is set.
          '';
        };
        parent.user = lib.mkOption {
          type = lib.types.str;
          default = if !builtins.isNull inUser then inUser else defaultOwner;
          description = ''
            Specify the user that owns the parent directory of this directory.
          '';
        };
        parent.group = lib.mkOption {
          type = lib.types.str;
          default =
            let
              owner = if !builtins.isNull inUser then inUser else defaultOwner;
            in
            config.users.users.${owner}.group;
          defaultText = "config.users.users.\${owner}.group";
          description = ''
            Specify the group that owns the parent directory of this directory.
          '';
        };
        parent.mode = lib.mkOption {
          type = lib.types.str;
          default = "0755";
          description = ''
            Specify the access mode of the parent directory of this directory.
            See the section `Mode` in {manpage}`tmpfiles.d(5)` for more information.
          '';
        };
        mountOptions = lib.mkOption {
          type = with lib.types; listOf (coercedTo str (n: { name = n; }) mountOption);
          description = ''
            Specify a list of mount options that should be used for this directory.
            These options are only used when {option}`how` is set to `bindmount`.
            By default, `bind` and `X-fstrim.notrim` are added,
            use `mkForce` to override these if needed.
            See also {manpage}`fstrim(8)`.
          '';
        };
        createLinkTarget = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Only used when {option}`how` is set to `symlink`.

            Specify whether to create an empty directory with the specified ownership
            and permissions as target of the symlink.
          '';
        };
        inInitrd = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether to prepare preservation of this directory in initrd.

            ::: {.note}
            For most directories there is no need to enable this option.
            :::

            ::: {.important}
            Note that both owner and group for this directory need to be
            available in the initrd for permissions to be set correctly.
            :::
          '';
        };
        inUser = lib.mkOption {
          type = with lib.types; nullOr str;
          internal = true;
          readOnly = true;
        };
      };

      config = {
        mountOptions = [
          "bind"
          "X-fstrim.notrim"
        ];
      };
    };

  filePath =
    attrs@{ defaultOwner, inUser ? null, ... }:
    {
      options = {
        file = lib.mkOption {
          type = lib.types.str;
          description = ''
            Specify the path to the file that should be preserved.
          '';
        };
        how = lib.mkOption {
          type = lib.types.enum [
            "bindmount"
            "symlink"
          ];
          default = "bindmount";
          description = ''
            Specify how this file should be preserved:

            1. Either a file is placed both on the volatile and on the
            persistent volume, with a bind mount from the former to the
            latter.

            2. Or a symlink is created on the volatile volume, pointing
            to the corresponding location on the persistent volume.
          '';
        };
        user = lib.mkOption {
          type = lib.types.str;
          default = defaultOwner;
          description = ''
            Specify the user that owns the file.
          '';
        };
        group = lib.mkOption {
          type = lib.types.str;
          default = config.users.users.${defaultOwner}.group;
          defaultText = "config.users.users.\${defaultOwner}.group";
          description = ''
            Specify the group that owns the file.
          '';
        };
        mode = lib.mkOption {
          type = lib.types.str;
          default = "0644";
          description = ''
            Specify the access mode of the file.
            See the section `Mode` in {manpage}`tmpfiles.d(5)` for more information.
          '';
        };
        configureParent = lib.mkOption {
          type = lib.types.bool;
          default =
            let
              isUserSymlink = attrs.config.how == "symlink" && attrs.config.user != "root";
              hasInUser = !builtins.isNull inUser;
              notOnTopLevel = !builtins.isNull (builtins.match ".+/.*" attrs.config.file);
            in
            (isUserSymlink || hasInUser) && notOnTopLevel;
          description = ''
            Specify whether the parent directory of this file shall be configured with
            custom ownership and permissions.

            By default, missing parent directories are always created with ownership
            `root:root` and mode `0755`, as described in {manpage}`tmpfiles.d(5)`.

            Ownership and mode may be configured through the options
            {option}`parent.user`,
            {option}`parent.group`,
            {option}`parent.mode`.

            Defaults to `true` when {option}`how` is set to `symlink` and
            {option}`user` is not `root`, or when {option}`inUser` is set.
          '';
        };
        parent.user = lib.mkOption {
          type = lib.types.str;
          default = if !builtins.isNull inUser then inUser else defaultOwner;
          description = ''
            Specify the user that owns the parent directory of this file.
          '';
        };
        parent.group = lib.mkOption {
          type = lib.types.str;
          default =
            let
              owner = if !builtins.isNull inUser then inUser else defaultOwner;
            in
            config.users.users.${owner}.group;
          defaultText = "config.users.users.\${owner}.group";
          description = ''
            Specify the group that owns the parent directory of this file.
          '';
        };
        parent.mode = lib.mkOption {
          type = lib.types.str;
          default = "0755";
          description = ''
            Specify the access mode of the parent directory of this file.
            See the section `Mode` in {manpage}`tmpfiles.d(5)` for more information.
          '';
        };
        mountOptions = lib.mkOption {
          type = with lib.types; listOf (coercedTo str (o: { name = o; }) mountOption);
          description = ''
            Specify a list of mount options that should be used for this file.
            These options are only used when {option}`how` is set to `bindmount`.
            By default, `bind` is added,
            use `mkForce` to override this if needed.
          '';
        };
        createLinkTarget = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Only used when {option}`how` is set to `symlink`.

            Specify whether to create an empty file with the specified ownership
            and permissions as target of the symlink.
          '';
        };
        inInitrd = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether to prepare preservation of this file in the initrd.

            ::: {.note}
            For most files there is no need to enable this option.

            {file}`/etc/machine-id` is an exception because it needs to
            be populated/read very early.
            :::

            ::: {.important}
            Note that both owner and group for this file need to be
            available in the initrd for permissions to be set correctly.
            :::
          '';
        };
        inUser = lib.mkOption {
          type = with lib.types; nullOr str;
          internal = true;
          readOnly = true;
        };
      };

      config = {
        mountOptions = [
          "bind"
        ];
      };
    };

  preserveAtSubmodule =
    attrs@{ name, ... }:
    {
      options = {
        inUser = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            Specify the user that owns the directories and files under this
            preservation prefix. When set, {option}`directories` and
            {option}`files` paths are interpreted relative to the user's
            home directory. The parent directory on persistent storage
            will be configured with the user's ownership and permissions.

            Defaults to `null` for system-level preservation.
          '';
          example = "alice";
        };
        username = lib.mkOption {
          type = with lib.types; passwdEntry str;
          default = if builtins.isNull attrs.config.inUser then "root" else attrs.config.inUser;
          internal = true;
          readOnly = true;
        };
        home = lib.mkOption {
          type = with lib.types; passwdEntry path;
          default =
            if builtins.isNull attrs.config.inUser then "/root"
            else config.users.users.${attrs.config.inUser}.home;
          defaultText = "config.users.users.\${inUser}.home";
          internal = true;
          readOnly = true;
        };
        persistentStoragePath = lib.mkOption {
          type = lib.types.path;
          default = name;
          description = ''
            Specify the location at which the {option}`directories` and {option}`files`
            should be preserved. Defaults to the name of the parent attribute set.
          '';
        };
        directories = lib.mkOption {
          type =
            with lib.types;
            listOf (
              coercedTo str (d: { directory = d; }) (submodule [
                {
                  _module.args.defaultOwner = attrs.config.username;
                  _module.args.inUser = attrs.config.inUser;
                  mountOptions = attrs.config.commonMountOptions;
                }
                directoryPath
              ])
            );
          default = [ ];
          apply =
            definedDirectories:
            let
              intermediateDirectorySettings = {
                how = "_intermediate";
                configureParent = false;
                user = attrs.config.username;
                group = config.users.users.${attrs.config.username}.group;
                mode = "0755";
              };
              allWithIntermediates =
                mkIntermediateUserDirectories intermediateDirectorySettings attrs.config.files attrs.config.home
                  definedDirectories;
            in
            if builtins.isNull attrs.config.inUser then
              allWithIntermediates
            else
              let
                # Split into original dirs and generated intermediates
                originalDirs = map (d: d // { directory = concatTwoPaths attrs.config.home d.directory; })
                  (builtins.filter (d: d.how != "_intermediate") allWithIntermediates);
                intermediates = map (d: d // { directory = concatTwoPaths attrs.config.home d.directory; })
                  (builtins.filter (d: d.how == "_intermediate") allWithIntermediates);
              in
              originalDirs ++ intermediates;
          description = ''
            Specify a list of directories that should be preserved.
            The paths are interpreted as absolute paths for system entries
            (when {option}`inUser` is `null`), or relative to the user's
            home directory when {option}`inUser` is set.
          '';
          example = [ "/var/lib/someservice" ];
        };
        files = lib.mkOption {
          type =
            with lib.types;
            listOf (
              coercedTo str (f: { file = f; }) (submodule [
                {
                  _module.args.defaultOwner = attrs.config.username;
                  _module.args.inUser = attrs.config.inUser;
                  mountOptions = attrs.config.commonMountOptions;
                }
                filePath
              ])
            );
          default = [ ];
          apply =
            if builtins.isNull attrs.config.inUser then
              lib.id
            else
              map (f: f // { file = concatTwoPaths attrs.config.home f.file; });
          description = ''
            Specify a list of files that should be preserved.
            The paths are interpreted as absolute paths for system entries
            (when {option}`inUser` is `null`), or relative to the user's
            home directory when {option}`inUser` is set.
          '';
          example = lib.literalMD ''
            ```nix
            [
              {
                file = "/etc/wpa_supplicant.conf";
                how = "symlink";
              }
              {
                file = "/etc/machine-id";
                inInitrd = true;
              }
            ]
            ```
          '';
        };
        commonMountOptions = lib.mkOption {
          type = with lib.types; listOf (coercedTo str (n: { name = n; }) mountOption);
          default = [ ];
          example = [
            "x-gvfs-hide"
            "x-gdu.hide"
          ];
          description = ''
            Specify a list of mount options that should be added to all files and directories
            under this preservation prefix, for which {option}`how` is set to `bindmount`.

            See also the individual
            {option}`mountOptions` that is available per file / directory.
          '';
        };
      };
    };

in
{
  options.preservation = {
    enable = lib.mkEnableOption "the preservation module";

    preserveAt = lib.mkOption {
      type =
        with lib.types;
        attrsWith {
          placeholder = "path";
          elemType = submodule preserveAtSubmodule;
        };
      description = ''
        Specify a set of locations and the corresponding state that
        should be preserved there.
      '';
      default = { };
      example = lib.literalMD ''
        ```nix
        {
          "/state" = {
            directories = [ "/var/lib/someservice" ];
            files = [
              {
                file = "/etc/wpa_supplicant.conf";
                how = "symlink";
              }
              {
                file = "/etc/machine-id";
                inInitrd = true;
              }
            ];
          };
          "/state/home-alice" = {
            inUser = "alice";
            directories = [ ".rabbit_hole" ".config/kitty" ];
          };
          "/state/home-butz" = {
            inUser = "butz";
            directories = [ "unshaved_yaks" ];
            files = [
              {
                file = ".config/foo";
                mode = "0600";
              }
              "bar"
            ];
          };
        }
        ```
      '';
    };
  };
}
