lib:
lib.extend (
  self: _super: {

    localName = name: name + "-local";

    # append "-local" to derivation pname, so not to step on others
    makeLocal = drv: drv.overrideAttrs { pname = self.localName drv.pname; };

  }
)
