_self: super:
let
  lib = import ./lib.nix super.lib;
in
{

  inherit lib;

  pythonPackagesExtensions = super.pythonPackagesExtensions ++ [
    (self: super: import ./py self super)
  ];

  acados = super.callPackage ./acados { };

  # using -local suffix so other packages depending on these do not need to be rebuilt

  ${lib.localName "libyuv"} = super.callPackage ./libyuv { };

  ${lib.localName "raygui"} = super.callPackage ./raygui { };

  ${lib.localName "raylib"} = super.callPackage ./raylib { };

}
