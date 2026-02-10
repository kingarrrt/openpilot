{ superPyPkgs, tinygrad-src }:
superPyPkgs.tinygrad.overrideAttrs {

  src = tinygrad-src;

  # nixpkgs drv does both, not wanted
  patches = [ ];
  postPatch = "";

  # too much
  doInstallCheck = false;

}
