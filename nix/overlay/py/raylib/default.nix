{
  lib,
  stdenv,
  apple-sdk,
  glfw3,
  raygui-local,
  raylib-local,
  superPyPkgs,
  ...
}:
lib.makeLocal (
  (superPyPkgs.raylib-python-cffi.override {
    raygui = raygui-local;
    raylib = raylib-local;
  }).overrideAttrs
    (drv: {
      buildInputs =
        drv.buildInputs ++ [ glfw3 ] ++ lib.optionals stdenv.isDarwin [ apple-sdk ];
    })
)
