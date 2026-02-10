lib:
lib.extend (
  self: _super: {

    # name for a local package
    localName = name: name + "-local";

    # append "-local" to derivation pname, so not to step on others
    makeLocal =
      drv:
      drv.overrideAttrs (drv: {
        pname = self.localName (drv.pname or drv.name);
      });

    deepMergePythonAttrs =
      left: right:
      let
        # Stop recursion if either side is not an attribute set (strings, ints, etc.)
        # or if we hit lists/derivations/special keys.
        stopRecursion =
          path: l: r:
          !(builtins.isAttrs l)
          || !(builtins.isAttrs r) # <-- ADD THIS
          || lib.isList l
          || lib.isList r
          || lib.isDerivation l
          || lib.isDerivation r
          || (path != [ ] && lib.last path == "optional-dependencies");

        safeExtras =
          l: r:
          let
            le =
              if lib.isAttrs l && lib.isAttrs (l.optional-dependencies or null) then
                l.optional-dependencies
              else
                { };
            re =
              if lib.isAttrs r && lib.isAttrs (r.optional-dependencies or null) then
                r.optional-dependencies
              else
                { };
          in
          if le == { } && re == { } then
            { }
          else
            builtins.zipAttrsWith (_: v: lib.unique (lib.concatLists v)) [
              le
              re
            ];
      in
      lib.recursiveUpdateUntil stopRecursion left right
      //
        lib.genAttrs
          (builtins.filter (a: left ? ${a} || right ? ${a}) [
            "build-system"
            "dependencies"
            "nativeCheckInputs"
          ])
          (
            a:
            lib.unique (
              (lib.toList (left.${a} or [ ])) ++ (lib.toList (right.${a} or [ ]))
            )
          )
      // lib.optionalAttrs (
        left ? optional-dependencies || right ? optional-dependencies
      ) { optional-dependencies = safeExtras left right; };

    deepMergePythonAttrs' =
      attrsList: lib.foldl' self.deepMergePythonAttrs { } attrsList;

  }
)
