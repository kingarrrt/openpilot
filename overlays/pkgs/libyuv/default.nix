{
  lib,
  fetchgit,
  libyuv,
}:

# TODO: check if nixpkgs version is acceptable

libyuv.overrideAttrs (pkg: {
  version = "1622"; # from include/libyuv/version.h
  src = fetchgit {
    inherit (pkg.src) url;
    rev = "4a14cb2e81235ecd656e799aecaaf139db8ce4a2";
    hash = "sha256-W5cgkVCqBR1VPHpNIhb7G+YYzX5BpwvIN5mhvOHMDto=";
  };
  cmakeFlags = with lib; [
    (cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.5")
    (cmakeBool "UNIT_TEST" true)
  ];
  # FIXME: unit test not built
  doCheck = false;
  # XXX: nixpkgs patch wanted?
  patches = [ ];
})
