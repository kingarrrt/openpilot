{
  lib,
  # pkgs
  llvmPackages,
  # python.pkgs
  loadPyproject,
  # self
  opendbc-src,
  # resolved by buildPyproject if not supplied
  pythonInterpreter ? null,
}:

let
  inherit
    (loadPyproject {
      src = opendbc-src;
      patches = [ ./opendbc.patch ];
      inherit pythonInterpreter;
      build-system = [ llvmPackages.clang ];
    })
    pyAttrs
    python
    ;
in
python.pkgs.buildPythonPackage (
  pyAttrs
  // {

    postPatch = "patchShebangs .";

    # needed for scons
    PYTHONPATH = ".";

    # runs an install script using sudo so no go in the nix sandbox
    disabledTests = [ "test_misra_mutation" ];

    # preBuild = ''
    #   scons -j$NIX_BUILD_CORES
    # '';

    # put headers in std location
    postInstall = ''
      tgt=$out/include/opendbc
      mkdir -p $tgt
      ln -s \
        $out/${python.sitePackages}/opendbc/safety \
        $out/include/opendbc/safety
    '';

  }
)
