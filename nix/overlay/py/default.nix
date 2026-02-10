self: super:
let

  inherit (super) pkgs;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  localPkgs = pkgs.mkLocalPkgs self ./.;

  openpilot = self.callPackage ../../../. { };

in
localPkgs
// {
  inherit localPkgs;

  localPkgSet = self.overrideScope (_: _: localPkgs);

  # needed for overrides otherwise there is infinite recursion
  superPyPkgs = super;

  # used by commaai component packages
  pythonInterpreter = openpilot.passthru.pythonModule;

  # python packages that don't live in python-modules must be converted
  codespell = super.toPythonModule (
    pkgs.codespell.override { python3 = super.python; }
  );
  scons = super.toPythonModule (
    pkgs.scons.override { python3Packages = self; }
  );
  ty = super.toPythonModule pkgs.ty;

  # tests failing
  pygame = super.pygame.overrideAttrs { doInstallCheck = false; };
  msal-extensions = super.msal-extensions.overrideAttrs {
    doCheck = !isDarwin;
  };
  trio-websocket = super.trio-websocket.overrideAttrs { doCheck = !isDarwin; };

}
