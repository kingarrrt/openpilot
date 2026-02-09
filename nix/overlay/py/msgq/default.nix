{
  # pkgs
  catch2,
  llvmPackages,
  ocl-icd,
  opencl-headers,
  zeromq,
  # python.pkgs
  buildPyproject,
  # self
  msgq-src,
  # resolved by buildPyproject if not supplied
  pythonInterpreter ? null,
}:

buildPyproject {

  src = msgq-src;
  patches = [ ./msgq.patch ];
  inherit pythonInterpreter;

  build-system = [
    catch2
    llvmPackages.clang
    ocl-icd
    opencl-headers
    zeromq
  ];

}
