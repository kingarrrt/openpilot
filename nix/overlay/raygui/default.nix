{
  lib,
  fetchFromGitHub,
  raygui,
}:

raygui.overrideAttrs (drv: {

  # UPSTREAM: raygui should use pname pattern, then this could use lib.makeLocal
  name = (lib.localName drv.name) + "-" + drv.version;

  src = fetchFromGitHub {
    inherit (drv.src) owner repo;
    rev = "76b36b597edb70ffaf96f046076adc20d67e7827";
    hash = "sha256-bH6bCYtGDuw5by3Z15eDqOSxP3AIn4rR+KNqYjt9r64=";
  };

})
