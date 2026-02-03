{
  lib,
  stdenv,
  apple-sdk,
  glfw3,
  raygui-local,
  raylib-local,
  raylib-python-cffi,
}:
lib.makeLocal (
  (raylib-python-cffi.override {
    raygui = raygui-local;
    raylib = raylib-local;
  }).overrideAttrs
    (drv: {
      buildInputs =
        drv.buildInputs ++ [ glfw3 ] ++ lib.optionals stdenv.isDarwin [ apple-sdk ];
    })
)
