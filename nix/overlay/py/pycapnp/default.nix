{ lib, superPyPkgs }:
lib.makeLocal (
  superPyPkgs.pycapnp.overrideAttrs (prev: rec {

    # nixpkgs currently has 2.0.0
    # there's an open pr bringing it to 2.2.2 https://github.com/NixOS/nixpkgs/pull/482314
    version = "2.1.0";

    src = prev.src.overrideAttrs {
      tag = "v${version}";
      hash = "sha256-btgBT/CJzn0ex76cwPZgt2XUffcxZjDlGKZNlDRYci0=";
    };

    # second patch pr is already merged
    patches = [ (builtins.head prev.patches) ];

  })
)
