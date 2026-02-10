{
  lib,
  stdenv,
  cmake,
  fetchFromGitHub,
  rustPlatform,
}:
stdenv.mkDerivation (finalAttrs: {

  pname = lib.localName "acados";
  version = "0.2.2";

  src = fetchFromGitHub {
    owner = finalAttrs.pname;
    repo = finalAttrs.pname;
    tag = "v${finalAttrs.version}";
    hash = "sha256-e9Wh2SsieJXfQw6KOKr8ECkbfDHtkKQ7Fk/Sf4yhzbA=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    # required for ACADOS_UNIT_TESTS
    # eigen
  ];

  cmakeFlags = with lib; [
    (cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.5")
    (cmakeFeature "ACADOS_INSTALL_DIR" (placeholder "out"))
    # FIXME: fails with
    #   error: size of array 'altStackMem' is not an integral constant-expression
    # (cmakeBool "ACADOS_UNIT_TESTS" true)
    "-UBLASFEO_TARGET"
    (cmakeFeature "BLASFEO_TARGET" "X64_AUTOMATIC")
  ];

  CFLAGS = map (warning: "-Wno-error=${warning}") [
    "implicit-function-declaration"
    "incompatible-pointer-types"
  ];

  postInstall = ''
    mkdir $out/bin
    ln -s ${
      rustPlatform.buildRustPackage {
        pname = "t_renderer";
        version = "0.1.0";
        src = finalAttrs.src + /interfaces/acados_template/tera_renderer;
        patchPhase = "ln -s ${./Cargo.lock}";
        cargoLock.lockFile = ./Cargo.lock;
      }
    }/bin/t_renderer $out/bin
    dir=$out/interfaces/acados_template/acados_template
    mkdir -p $dir
    cp ${./acados_layout.json} $dir/acados_layout.json
  '';

  passthru.to_upstream = true;

})
