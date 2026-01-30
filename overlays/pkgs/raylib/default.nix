{
  lib,
  stdenv,
  fetchFromGitHub,
  libGLU,
  libX11,
  libxrandr,
  libxinerama,
  libxi,
  libxcursor,
  fetchurl,
}:

# TODO:
# if [ -f /TICI ]; then
#
#   RAYLIB_PLATFORM="PLATFORM_COMMA"
#
#   # Building the python bindings
#   cd $DIR
#
#   if [ ! -d raylib_python_repo ]; then
#     git clone -b master --no-tags https://github.com/commaai/raylib-python-cffi.git raylib_python_repo
#   fi
#
#   cd raylib_python_repo
#
#   BINDINGS_COMMIT="a0710d95af3c12fd7f4b639589be9a13dad93cb6"
#   git fetch origin $BINDINGS_COMMIT
#   git reset --hard $BINDINGS_COMMIT
#   git clean -xdff .
#
#   RAYLIB_PLATFORM=$RAYLIB_PLATFORM RAYLIB_INCLUDE_PATH=$INSTALL_H_DIR RAYLIB_LIB_PATH=$INSTALL_DIR python setup.py bdist_wheel
#   cd $DIR
#
#   rm -rf wheel
#   mkdir wheel
#   cp raylib_python_repo/dist/*.whl wheel/
#
# fi

stdenv.mkDerivation {

  pname = "raylib";
  version = "5.5-commaai";

  enableParallelBuilding = true;

  src = fetchFromGitHub {
    owner = "commaai";
    repo = "raylib";
    rev = "3425bd9d1fb292ede4d80f97a1f4f258f614cffc";
    hash = "sha256-mDeVxWQCCTZgzkWlrDmjuS3Y/JIJowFjo1N94pLOzMw=";
  };

  propagatedBuildInputs = [
    libxcursor
    libxi
    libxinerama
    libxrandr
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    libGLU
    libX11
  ];

  makeFlags = [
    "-C src"
    "PLATFORM=PLATFORM_DESKTOP"
    "DESTDIR=${placeholder "out"}"
    # Makefile will only install for root user
    "ROOT=root"
  ];

  postInstall = ''
    cp ${
      fetchurl {
        url = "https://raw.githubusercontent.com/raysan5/raygui/76b36b597edb70ffaf96f046076adc20d67e7827/src/raygui.h";
        hash = "sha256-KanHv4y+qTqXvbCtONod0eHd+ybJ61Mb/mfWjAV9xy8=";
      }
    } $out/include/raygui.h
  '';

}
