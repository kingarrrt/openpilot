self: super:
let
  inherit (super) pkgs;
  inherit (pkgs) lib;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  inherit (self) callPackage;
in
{

  acados-template = callPackage ./acados-template { };

  codespell = super.toPythonModule (
    pkgs.codespell.override { python3 = super.python; }
  );

  crcmod-plus = callPackage ./crdmod-plus { };

  dearpygui = callPackage ./dearpygui { };

  ${lib.localName "hypothesis"} = callPackage ./hypothesis { };

  inputs = callPackage ./inputs { };

  metadrive-simulator = callPackage ./metadrive-simulator { };

  msal-extensions = super.msal-extensions.overrideAttrs {
    doInstallCheck = !isDarwin;
  };

  ${lib.localName "pycapnp"} = callPackage ./pycapnp { };

  # tests fail under py312
  pygame = super.pygame.overrideAttrs { doInstallCheck = false; };

  pytest-cpp = callPackage ./pytest-cpp { };

  ${lib.localName "pytest-xdist"} = callPackage ./pytest-xdist { };

  raylib = callPackage ./raylib-python-cffi { };

  # scons is not part of the python package set so must converted
  scons = super.toPythonModule (
    # otherwise it gets pkgs.python3Packages and we have 2 pythons in the closure
    pkgs.scons.override { python3Packages = self; }
  );

  trio-websocket = super.trio-websocket.overrideAttrs { doCheck = !isDarwin; };

  # per scons
  ty = super.toPythonModule pkgs.ty;

}
