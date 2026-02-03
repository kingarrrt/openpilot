{
  lib,
  cachix,
  pre-commit,
  mermaid-cli,
  mkShell,
  nix-output-monitor,
  openpilot,
}:
mkShell (
  {

    inherit (openpilot) name;

    # don't bother trying to get this from a binary cache
    preferLocalBuild = true;
    allowSubstitutes = false;

    # make available all build and runtime inputs
    inputsFrom = [ openpilot ];

    # extra packages
    packages =
      # non-python
      [
        cachix
        mermaid-cli
        # nix build sugar
        nix-output-monitor
        # python interpreter
        openpilot.passthru.pythonModule
      ]
      # python packages from ./pyproject.toml optional-dependencies
      ++ (
        with lib;
        flatten (
          mapAttrsToList (_name: drvs: drvs) (
            # TODO: tools package expressions are unfinished
            filterAttrs (name: _drvs: name != "tools") openpilot.optional-dependencies
          )
        )
      )
      ++ pre-commit.enabledPackages;

    # sourced on shell init
    shellHook = ''
      ${pre-commit.shellHook}
      PATH=$PWD/result/bin:$PATH
    '';

  }
  # bring in env vars
  // (with lib; filterAttrs (name: _value: toUpper name == name) openpilot)

)
