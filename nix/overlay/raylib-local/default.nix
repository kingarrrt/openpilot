{
  lib,
  stdenv,
  fetchFromGitHub,
  libxcursor,
  libxi,
  libxinerama,
  libxrandr,
  raylib,
}:
let
  inherit (stdenv.hostPlatform) isDarwin isLinux;
in
lib.makeLocal (
  (raylib.override { sharedLib = !isDarwin; }).overrideAttrs (drv: {

    version = "git";

    src = fetchFromGitHub {
      owner = "commaai";
      repo = "raylib";
      rev = "3425bd9d1fb292ede4d80f97a1f4f258f614cffc";
      hash = "sha256-mDeVxWQCCTZgzkWlrDmjuS3Y/JIJowFjo1N94pLOzMw=";
    };

    propagatedBuildInputs =
      drv.propagatedBuildInputs
      ++ lib.optionals (!isDarwin) [
        libxcursor
        libxrandr
        libxi
        libxinerama
      ];

    NIX_LDFLAGS = lib.concatStringsSep " " (
      [ "-lglfw" ]
      ++ lib.optionals isLinux [
        "-lGL"
        "-lX11"
      ]
      ++ lib.optionals isDarwin (
        map (f: "-framework ${f}") [
          "AppKit"
          "CoreGraphics"
          "CoreVideo"
          "Foundation"
          "IOKit"
          "OpenGL"
        ]
      )
    );

    cmakeFlags =
      (drv.cmakeFlags or [ ])
      ++ lib.optionals isDarwin [ "-DCMAKE_MACOSX_RPATH=ON" ];

  })
)
