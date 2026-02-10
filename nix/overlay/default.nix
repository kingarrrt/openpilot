inputs: self: super:
let

  lib = import ./lib.nix super.lib;

  mkLocalPkgs =
    self: path:
    builtins.mapAttrs (name: _type: self.callPackage "${path}/${name}" { }) (
      lib.filterAttrs (name: type: type == "directory" && name != "py") (
        builtins.readDir path
      )
    );

  localPkgs = mkLocalPkgs self ./.;

in
localPkgs
// inputs
// {

  inherit lib localPkgs mkLocalPkgs;

  pythonPackagesExtensions = super.pythonPackagesExtensions ++ [
    (self: super: import ./py self super)
  ];

  loadPyproject =
    {
      src,
      patch ? null,
      pythonInterpreter ? null,
      ...
    }@attrs:

    let

      patchedSrc =
        if (patch != null) then
          self.applyPatches {
            name = builtins.baseNameOf patch;
            inherit src;
            patches = [ patch ];
            allowSubstitutes = true;
          }
        else
          src;

      project = inputs.pyproject-nix.lib.project.loadPyproject {
        projectRoot = patchedSrc;
      };

      # if not supplied with a python3 use the best available python within the
      # project.requires-python constraint
      python =
        if pythonInterpreter == null then
          builtins.head (
            inputs.pyproject-nix.lib.util.filterPythonInterpreters {
              inherit (project) requires-python;
              inherit (self) pythonInterpreters;
            }
          )
        else
          pythonInterpreter;

      pyAttrs =
        let
          replaceLocals =
            value:
            if lib.isDerivation value then
              python.pkgs.localPkgs.${lib.localName (value.pname or value.name or "")}
                or value
            else if (lib.isList value) then
              map replaceLocals value
            else if (lib.isAttrs value) then
              lib.mapAttrs (_n: replaceLocals) value
            else
              value;
        in
        replaceLocals (
          lib.deepMergePythonAttrs' [
            # render package attrs
            (project.renderers.buildPythonPackage {
              inherit python;
              pythonPackages = python.pkgs.localPkgSet;
              extrasAttrMappings = {
                docs = "nativeCheckInputs";
                testing = "nativeCheckInputs";
              };
            })
            # defaults
            { nativeCheckInputs = with python.pkgs; [ pytestCheckHook ]; }
            # from args
            (builtins.removeAttrs attrs [
              "src"
              "pythonInterpreter"
              "patches"
            ])
            # if src was patched then add it as a dependency so its not garbage
            # collected
            (lib.optionalAttrs (src != patchedSrc) { build-system = [ patchedSrc ]; })
          ]
        );

    in
    {
      inherit project pyAttrs python;
    }
    // {
      pyAttrs = lib.deepMergePythonAttrs' [
        pyAttrs
        {

          # append git short rev as local label
          version =
            let
              shortRev = src.shortRev or src.dirtyShortRev or null;
            in
            pyAttrs.version + (if (shortRev != null) then "+g" + shortRev else "");

          # pass through include and library paths
          env = with lib; {
            CPPPATH = makeIncludePath (map getInclude (pyAttrs.build-system or [ ]));
            LIBPATH = makeLibraryPath (map getLib (pyAttrs.build-system or [ ]));
          };

          # run scons if the project uses it
          preBuild =
            if
              (builtins.any (drv: (drv.pname or drv.name or "") == "scons") (
                pyAttrs.build-system or [ ]
              ))
            then
              "scons --jobs=$NIX_BUILD_CORES"
            else
              "";

          # UPSTREAM: should be done by pyproject-nix
          pythonImportsCheck =
            pyAttrs.pythonImportsCheck or [ (pyAttrs.pname or pyAttrs.name) ];

          # TOGO: for dev
          passthru = { inherit project pyAttrs; };

        }
      ];
    };

  buildPyproject =
    args:
    let
      inherit (self.loadPyproject args) pyAttrs python;
    in
    python.pkgs.buildPythonPackage pyAttrs;

}
