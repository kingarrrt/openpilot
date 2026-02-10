{
  # pkgs
  llvmPackages,
  rsync,
  # python.pkgs
  buildPyproject,
  # self
  opendbc-src,
  # resolved by buildPyproject if not supplied
  pythonInterpreter ? null,
}:
buildPyproject {

  src = opendbc-src;
  patches = [ ./opendbc.patch ];

  inherit pythonInterpreter;

  build-system = [
    llvmPackages.clang
    rsync
  ];

  postPatch = "patchShebangs .";

  # scons assumes
  PYTHONPATH = ".";

  # runs an install script using sudo
  disabledTests = [ "test_misra_mutation" ];

  # install headers in std location
  postInstall = ''
    tgt=$out/include
    mkdir -p $tgt
    find opendbc -name "*.h" -exec cp --parents \{\} $tgt \;
  '';

}
