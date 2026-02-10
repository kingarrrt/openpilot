{
  # pkgs
  llvmPackages,
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

  postInstall = ''
    # install headers
    tgt=$out/include/panda
    mkdir -p $tgt
    find . -name "*.h" -exec cp --parents \{\} $tgt \;
  '';

  pythonImportsCheck = [ "panda" ];

  # flaky
  doCheck = false;

}
