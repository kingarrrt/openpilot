{
  # pkgs
  eigen,
  llvmPackages,
  # python.pkgs
  buildPyproject,
  # self
  rednose-src,
  # resolved by buildPyproject if not supplied
  pythonInterpreter ? null,
}:
buildPyproject {

  src = rednose-src;
  patches = [ ./rednose.patch ];

  inherit pythonInterpreter;

  build-system = [
    eigen
    llvmPackages.clang
  ];

  postPatch = "patchShebangs .";

  # scons assumes
  PYTHONPATH = ".";

}
