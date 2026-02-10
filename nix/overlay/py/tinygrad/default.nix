{ superPyPkgs }:
superPyPkgs.tinygrad.overrideAttrs (prev: {

  src = prev.src.overrideAttrs {
    rev = "774a454bb5e6d0fe3756a8add9302c0a3d592bd9";
    hash = "sha256-CHZau1aArEOk5bdMIU0H6yM6B2JsucIiom5n8sdUyF8=";
  };

  # nixpkgs drv does both, not wanted
  patches = [ ];
  postPatch = "";

  # too much
  doInstallCheck = false;

})
