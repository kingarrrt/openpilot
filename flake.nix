{

  # configure the binary cache
  nixConfig = {
    extra-substituters = [ "https://openpilot.cachix.org" ];
    extra-trusted-public-keys = [
      "openpilot.cachix.org-1:ZKgXqmM2hidKa9zHvVZXR/uFr2cY4rjEgs8BwNvVMk8="
    ];
  };

  inputs = {

    # tracking nixpkgs-unstable, see https://wiki.nixos.org/wiki/Channel_branches
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # provides saveFromGC, used below
    cache-nix-action = {
      url = "github:nix-community/cache-nix-action";
      flake = false;
    };

    # provides eachDefaultSystem, used below
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    # pre-commit integration
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # provides loadPyproject, used by ./default.nix
    pyproject-nix = {
      # TODO: use upstream pending https://github.com/pyproject-nix/pyproject.nix/pull/403
      url = "github:kingarrrt/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # default systems are:
    # - aarch64-darwin
    # - aarch64-linux
    # - x86_64-darwin
    # - x86_64-linux
    systems.url = "github:nix-systems/default";

    # commaai components
    msgq-src = {
      url = "github:commaai/msgq/20f2493855ef32339b80f0ad76b3cb82210dc474";
      flake = false;
    };

    opendbc-src = {
      url = "github:commaai/opendbc/e76c2cf5bb0042bc5822efa78fff0362feed7b54";
      flake = false;
    };

    panda-src = {
      url = "github:commaai/panda/81615ad9d53aef5583e064f340e9cdeb23d4119c";
      flake = false;
    };

    rednose-src = {
      url = "github:commaai/rednose/7fddc8e6d49def83c952a78673179bdc62789214";
      flake = false;
    };

    teleoprtc-src = {
      url = "github:commaai/teleoprtc/389815b8ca5302ce7c1504b7841d4eb61a8cd51b";
      flake = false;
    };

    cache.url = "git+https://github.com/kingarrrt/openpilot.git?rev=c3a2287899aff540a077bb3dec82c8540f58e131&lfs=1";

  };

  outputs =
    inputs:
    (inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let

        # the nix packages collection
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [ (import ./nix/overlay inputs) ];
        };
        inherit (pkgs) lib callPackage;

        # the openpilot package
        openpilot = callPackage ./. {
          inherit (inputs.cache.packages.${system}.default) sconsCache;
        };

        # pre-commit config
        pre-commit = callPackage ./nix/pre-commit.nix { inherit system; };

      in
      {

        # `nix flake check`
        checks = {
          inherit pre-commit;
          # lint = lintcfg.build.check inputs.self;
        };

        # `nix develop`
        devShells.default = callPackage ./nix/shell.nix {
          inherit openpilot pre-commit;
        };

        # `nix build` for default package, otherwise `nix build .#<name>`
        packages = {

          default = openpilot;

          release = openpilot.override { sconsCache = null; };

          # for dev:
          #  - nix build --impure .#pkgs.acados
          #  - nix build --impure .#python.pkgs.acados-template
          # inherit pkgs;
          # python = openpilot.passthru.pythonModule;

          # `nix profile add .#saveFromGC`
          #
          # derivations produced from flake inputs don't have references to the inputs,
          # so the inputs are candidates for garbage collection - this adds a gc root
          # for the inputs
          #
          # https://nix.dev/manual/nix/2.31/package-management/garbage-collector-roots
          # https://github.com/nix-community/cache-nix-action#savefromgc-example
          saveFromGC =
            (import "${inputs.cache-nix-action}/saveFromGC.nix" {
              inherit pkgs;
              inputs = lib.filterAttrs (name: _value: name != "cache") inputs;
            }).package;

        };

      }
    ));

}
