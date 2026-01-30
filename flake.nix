{

  nixConfig = {
    extra-substituters = [ "https://openpilot.cachix.org" ];
    extra-trusted-public-keys = [
      "openpilot.cachix.org-1:T0JsExXBYme8Hw2GQIONlQRXIWYKAm/vb3CgsrUypX8="
    ];
  };

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    pyproject-nix = {
      # pending https://github.com/pyproject-nix/pyproject.nix/pull/403
      url = "github:kingarrrt/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { self, ... }@inputs:
    let

      inherit (inputs.nixpkgs) lib;

      systems = import inputs.systems;

      perSystem = lib.genAttrs systems;

      systemPkgs =
        system:
        import inputs.nixpkgs {
          inherit system;
          overlays = [ (import ./overlays/pkgs { inherit (inputs) pyproject-nix; }) ];
        };

    in
    {

      packages = perSystem (
        system:
        let

          pkgs = systemPkgs system;

          project = inputs.pyproject-nix.lib.project.loadPyproject { projectRoot = ./.; };

          # get the best available python; constrained by ./pyproject.toml requires-python
          python =
            (builtins.head (
              inputs.pyproject-nix.lib.util.filterPythonInterpreters {
                inherit (project) requires-python;
                inherit (pkgs) pythonInterpreters;
              }
            )).override
              { packageOverrides = import ./overlays/python-pkgs; };

          pkg = pkgs.callPackage ./package.nix { inherit project python; };

          pytestFlags = pkg: flags: pkg.pytestFlags or [ ] ++ flags;

          exitfirstFlags = pkg: pytestFlags pkg [ "--exitfirst" ];

        in
        rec {

          default = pkg;

          inherit (pkg.passthru) test;

          test-existfirst = test.overrideAttrs (pkg: {
            pname = pkg.pname + "-existfirst";
            pytestFlags = exitfirstFlags pkg;
          });

          test-fast = test.overrideAttrs (pkg: {
            pname = pkg.pname + "-test-fast";
            disabledTestPaths = pkg.disabledTestPaths or [ ] ++ [
              "selfdrive/car/tests/test_car_interfaces.py"
              "selfdrive/car/tests/test_models.py"
            ];
          });

          test-fast-exitfirst = test-fast.overrideAttrs (pkg: {
            pname = pkg.pname + "-test-fast-exitfirst";
            pytestFlags = exitfirstFlags pkg;
          });

          # for dev
          inherit pkgs;
          pyPkgs = python.pkgs;

        }
      );

      devShells = perSystem (
        system:
        let
          pkgs = systemPkgs system;
          pkg = self.packages.${system}.default;
        in
        {
          default = pkgs.mkShell (
            {
              name = pkg.name + "-devshell";
              preferLocalBuild = true;
              allowSubstitutes = false;
              inputsFrom = [ pkg ];
              packages =
                (with pkgs; [
                  cachix
                ])
                ++ (lib.flatten (
                  lib.mapAttrsToList (_name: drvs: drvs) (
                    # TODO: tools
                    lib.filterAttrs (name: _drvs: name != "tools") pkg.optional-dependencies
                  )
                ));
            }
            // pkg.passthru.env
          );
        }
      );

    };

}
