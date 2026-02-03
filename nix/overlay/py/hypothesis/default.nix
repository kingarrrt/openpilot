{
  lib,
  fetchFromGitHub,
  hypothesis,
}:
lib.makeLocal (
  hypothesis.overrideAttrs (drv: rec {
    version = "6.47.5";
    src = fetchFromGitHub {
      owner = "HypothesisWorks";
      repo = drv.pname;
      tag = "${drv.pname}-python-${version}";
      hash = "sha256-yMIV3MgjtRXJ9vDp3Ko/si3SeH4OwjGBzdWhR+JDF38=";
    };
    # TODO: run tests, or rather upgrade to latest
    doInstallCheck = false;
  })
)
