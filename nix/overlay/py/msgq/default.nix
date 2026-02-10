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

  postInstall = ''
    # install lib
    cp *.a $out/lib
    # install headers
    tgt=$out/include
    mkdir -p $tgt
    find msgq -name "*.h" -exec cp --parents \{\} $tgt \;
  '';

}
