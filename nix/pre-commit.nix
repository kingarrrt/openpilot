{
  lib,
  system,
  codespell,
  git-hooks,
  ty,
}:
git-hooks.lib.${system}.run {

  hooks =
    with lib;
    recursiveUpdate
      (
        (genAttrs
          [
            # TODO: verifu scripts/lint/lint.sh

            # pre-commit
            "check-added-large-files"
            "check-merge-conflicts"
            # "check-shebang-scripts-are-executable"
            # nix
            "deadnix"
            # "flake-checker"
            "nixfmt"
            "statix"
            # python
            "ruff"
            # gpt commit message, OPENAI_API_KEY must be set in your environment
            # "gptcommit"
          ]
          (_name: {
            enable = true;
          })
        )
        // (listToAttrs (
          map
            (drv: {
              inherit (drv) name;
              value = {
                enable = true;
                entry = lib.getExe drv;
              };
            })
            [
              codespell
              # ty
            ]
        ))
      )
      {

        # default is 100, is not a hard limit - this makes it in effect 95
        nixfmt.settings.width = 77;

        ty.entry = "${lib.getExe ty} check";

      };

  src = ./.;

  # filter submodules
  # src = lib.cleanSourceWith {
  #   src = ./.;
  #   filter =
  #     path: _type:
  #     let
  #       relPath = lib.removePrefix ./. path;
  #       submodulePaths =
  #         let
  #           prefix = "\tpath = ";
  #           content = builtins.readFile ./.gitmodules;
  #         in
  #         map (line: lib.removePrefix prefix line) (
  #           builtins.filter (line: lib.hasPrefix prefix line) (lib.splitString "\n" content)
  #         );
  #     in
  #     !(builtins.elem (builtins.head relPath) (submodulePaths ++ [ "third_party" ]));
  # };

}
