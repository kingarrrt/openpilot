{
  lib,
  # pkgs
  llvmPackages,
  tree,
  gcc-arm-embedded,
  # python.pkgs
  buildPyproject,
  opendbc,
  # self
  panda-src,
  # resolved by buildPyproject if not supplied
  pythonInterpreter ? null,
}:
buildPyproject {

  src = panda-src;
  patches = [ ./panda.patch ];

  inherit pythonInterpreter;

  build-system = [
    llvmPackages.clang
    gcc-arm-embedded
    opendbc
  ];

  GIT_REV = panda-src.shortRev or panda-src.dirtyShortRev;

  postPatch = "patchShebangs crypto/sign.py";

  # preCheck = ''
  #   # echo $PYTHONPATH
  #   ${lib.getExe tree} board
  #   exit 1
  # '';

  pythonImportsCheck = [ "panda" ];
  # pythonImportsCheck = [ ];

  # doCheck = false;

}
