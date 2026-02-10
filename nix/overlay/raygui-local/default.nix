{ lib, raygui }:

raygui.overrideAttrs (prev: {

  # UPSTREAM: raygui should use pname pattern, then this could use lib.makeLocal
  name = (lib.localName prev.pname or prev.name) + "-" + prev.version;

  src = prev.src.overrideAttrs {
    rev = "76b36b597edb70ffaf96f046076adc20d67e7827";
    hash = "sha256-bH6bCYtGDuw5by3Z15eDqOSxP3AIn4rR+KNqYjt9r64=";
  };

})
