self: super:
let
  inherit (super) pkgs;
  inherit (pkgs) fetchFromGitHub;
in
{

  acados-template = self.callPackage ./acados-template { };

  codespell = super.toPythonModule pkgs.codespell;

  crcmod-plus = self.callPackage ./crdmod-plus { };

  dearpygui = self.callPackage ./dearpygui { };

  hypothesis-local = super.hypothesis.overrideAttrs (pkg: rec {
    version = "6.47.5";
    src = fetchFromGitHub {
      owner = "HypothesisWorks";
      repo = pkg.pname;
      tag = "${pkg.pname}-python-${version}";
      hash = "sha256-yMIV3MgjtRXJ9vDp3Ko/si3SeH4OwjGBzdWhR+JDF38=";
    };
    # TODO: run tests, or rather upgrade to latest
    doInstallCheck = false;
  });

  inputs = self.callPackage ./inputs { };

  metadrive-simulator = self.callPackage ./metadrive-simulator { };

  # TOGO: nixpkgs currently on 2.0.0
  pycapnp = super.pycapnp.overrideAttrs (pkg: rec {
    version = "2.1.0";
    src = fetchFromGitHub {
      owner = "capnproto";
      repo = pkg.pname;
      tag = "v${version}";
      hash = "sha256-btgBT/CJzn0ex76cwPZgt2XUffcxZjDlGKZNlDRYci0=";
    };
    # second patch pr is already merged
    patches = [ (builtins.head pkg.patches) ];
  });

  # FIXME: why tests fail?
  pygame = super.pygame.overrideAttrs { doInstallCheck = false; };

  pytest-cpp = self.callPackage ./pytest-cpp { };

  # TODO: pull request is dead - review current state of play
  pytest-xdist-local = super.pytest-xdist.overrideAttrs {
    pname = "pytest-xdist-local";
    patches = [
      (pkgs.fetchpatch {
        url = "https:/github.com/pytest-dev/pytest-xdist/pull/1229.patch";
        hash = "sha256-zkUN/gQ5o+4w9yaSl8j1oYqzJ1rITZU/Zm2nqpewNpk=";
      })
    ];
  };

  # NOTE: python raylib is in nixpkgs as raylib-python-cffi, we can't alias it to raylib
  # with `raylib = super.raylib-python-cffi` as this would make an infinite recursion
  # XXX: should be using https://github.com/commaai/raylib-python-cffi?
  raylib =
    (pkgs.callPackage "${pkgs.path}/pkgs/development/python-modules/raylib-python-cffi" {
      inherit (super) buildPythonPackage cffi setuptools;
      raylib = pkgs.raylib-commaai;
    }).overrideAttrs
      rec {
        RAYLIB_LINK_ARGS = "-L${pkgs.raylib-commaai}/lib -lraylib";
        RAYLIB_INCLUDE_PATH = "${pkgs.raylib-commaai}/include";
        RAYGUI_INCLUDE_PATH = RAYLIB_INCLUDE_PATH;
      };

}
