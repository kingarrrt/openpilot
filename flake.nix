{

  # configure the binary cache
  nixConfig = {
    extra-substituters = [ "https://openpilot.cachix.org" ];
    extra-trusted-public-keys = [
      "openpilot.cachix.org-1:ZKgXqmM2hidKa9zHvVZXR/uFr2cY4rjEgs8BwNvVMk8="
    ];
  };

  inputs = {

    self.submodules = true;

    # tracking nixpkgs-unstable, see https://wiki.nixos.org/wiki/Channel_branches
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # provides saveFromGC, used below
    cache-nix-action = {
      url = "github:nix-community/cache-nix-action";
      flake = false;
    };

    # provides eachDefaultSystem, used below
    flake-utils.url = "github:numtide/flake-utils";

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

  };

  outputs =
    inputs:
    let

      # overlay flake inputs and local overrides
      overlays = [
        (_: _: inputs)
        (import ./nix/overlay)
      ];

    in
    (inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let

        # the nixpkgs package collection,
        pkgs = import inputs.nixpkgs { inherit overlays system; };
        inherit (pkgs) lib;

        # the openpilot package
        #  pkgs.callPackage resolves arguments in its parent's scope (pkgs), "./." is
        #  shorthand for "./default.nix"
        openpilot = pkgs.callPackage ./. { };

        pre-commit = pkgs.callPackage ./nix/pre-commit.nix { inherit system; };

      in
      {

        # `nix flake check`
        checks = { inherit pre-commit; };

        # `nix develop`
        devShells.default = pkgs.callPackage ./nix/shell.nix {
          inherit openpilot pre-commit;
        };

        # `nix fmt`
        # formatter =
        #   let
        #     inherit (pre-commit.config) package configFile;
        #   in
        #   pkgs.writeShellScriptBin "pre-commit-run" ''
        #     ${pkgs.lib.getExe package} run --all-files --config ${configFile} nixfmt
        #   '';

        # `nix build` for default package, otherwise `nix build .#<name>`
        packages = {
          default = openpilot;
        }
        // lib.optionalAttrs (builtins.getEnv "IN_NIX_SHELL" != "") {

          # for dev:
          #  - nix build .#pkgs.acados
          #  - nix build .#pyPkgs.acados-template
          inherit pkgs;
          pyPkgs = openpilot.passthru.pythonModule.pkgs;

          # `nix profile add .#saveFromGC`
          #
          # derivations produced from flake inputs don't have references to the inputs,
          # so the inputs are candidates for garbage collection - this adds a gc root
          # for the inputs
          #
          # https://nix.dev/manual/nix/2.31/package-management/garbage-collector-roots
          # https://github.com/nix-community/cache-nix-action#savefromgc-example
          saveFromGC =
            (import "${inputs.cache-nix-action}/saveFromGC.nix" { inherit pkgs inputs; })
            .package;
        };

      }
    ))
    // {
      overlays.default = inputs.nixpkgs.lib.composeManyExtensions overlays;
    };

}
