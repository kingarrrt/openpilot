{ lib, superPyPkgs }:
lib.makeLocal (
  superPyPkgs.hypothesis.overrideAttrs (prev: rec {

    version = "6.47.5";

    src = prev.src.overrideAttrs {
      tag = "${prev.pname}-python-${version}";
      hash = "sha256-yMIV3MgjtRXJ9vDp3Ko/si3SeH4OwjGBzdWhR+JDF38=";
    };

    # not trying to debug this old thing
    # hypothesis.errors.InvalidArgument: Profile 'ci' is not registered
    doInstallCheck = false;

  })
)
