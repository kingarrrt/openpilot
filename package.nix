{
  lib,
  stdenv,
  acados,
  blasfeo,
  bzip2,
  cacert,
  capnproto,
  catch2,
  curl,
  eigen,
  ffmpeg,
  gcc,
  gcc-arm-embedded,
  gitMinimal,
  glibc,
  hpipm,
  libGL,
  libjpeg,
  libsForQt5,
  libusb1,
  libyuv-commaai,
  llvm,
  llvmPackages,
  ncurses,
  ocl-icd,
  opencl-headers,
  openssl,
  qpoases,
  raylib-commaai,
  rsync,
  sudo,
  scons,
  zeromq,
  zstd,
  # flake inputs
  project,
  python,
}:
let

  inherit (project.pyproject.tool.hatch.build.targets.wheel) packages;

  pyAttrs = project.renderers.buildPythonPackage { inherit python; };

  makeHome = ''
    # ./selfdrive/modeld/SConscript calls tinygrad which uses HOME for a cache
    # the tests assume home exists (which it does not in the nix sandbox)
    export HOME=$(mktemp -d)
  '';

  pkg =
    let

      sitePackages = "${builtins.placeholder "out"}/${python.sitePackages}";

      pkg = python.pkgs.buildPythonPackage (
        finalAttrs:
        (
          pyAttrs
          // {

            doCheck = false;
            doInstallCheck = false;
            dontPatchELF = true;
            # from qtbase setupHook, not necessary
            dontPatchMkspecs = true;
            dontPatchShebangs = true;
            dontWrapQtApps = true;
            enableParallelBuilding = true;
            noAuditTmpdir = true;
            # HACK: the nix python package build creates a wheel and then extracts it
            # which is slow but guaranteed deterministic - this package is verifiably
            # deterministic (nix build && nix build --rebuild) with the wheel creation
            # skipped
            pyproject = false;

            # TODO: filter out everything that does not affect the build to avoid
            # unnecessary rebuilds
            src =
              with lib.fileset;
              (toSource rec {
                root = pyAttrs.src;
                fileset = fileFilter (
                  file:
                  !(builtins.any file.hasExt [
                    "nix"
                    "lock"
                  ])
                ) root;
              });

            # TODO: /usr/bin/env is not available in the nix sandbox: adjust SConscripts
            # to call scripts as `python <script>` so this can be removed
            patchPhase = ''
              patchShebangs \
                opendbc_repo/opendbc/dbc/generator/*/*.py \
                panda/crypto/sign.py \
                selfdrive/locationd/models/car_kf.py \
                selfdrive/locationd/models/pose_kf.py
            '';

            nativeBuildInputs = [
              acados
              blasfeo
              bzip2
              capnproto
              catch2
              curl
              eigen
              ffmpeg
              gcc
              # FIXME: ./panda/SConscript tries to get git revision which don't work in
              # a nix build because the .git directory is stripped
              gitMinimal
              hpipm
              libjpeg
              libsForQt5.qtbase
              libsForQt5.qt5.qtcharts
              libsForQt5.qt5.qtserialbus
              libusb1
              libyuv-commaai
              llvmPackages.clang
              ncurses
              ocl-icd
              opencl-headers
              openssl
              qpoases
              raylib-commaai
              # otherwise scons will use default python3
              (scons.override { python3Packages = python.pkgs; })
              zeromq
              zstd
            ]
            ++ lib.optionals stdenv.hostPlatform.isLinux [
              gcc-arm-embedded
              libGL
            ]
            ++ (with python.pkgs; [
              build
              cython
              packaging
              pycapnp
            ]);

            # like this so the passthru env is available to the dev shell
            passthru.env = {
              ACADOS_SOURCE_DIR = acados;
              ACADOS_TEMPLATE_DIR = python.pkgs.acados-template + "/" + python.sitePackages + "/acados_template";
              CPPPATH = lib.makeIncludePath (map lib.getInclude finalAttrs.nativeBuildInputs);
              LIBPATH = lib.makeLibraryPath (map lib.getLib finalAttrs.nativeBuildInputs);
            }
            // lib.optionalAttrs stdenv.hostPlatform.isLinux {
              # tinygrad
              LIBC_PATH = "${lib.getLib glibc}/lib/libc.so.6";
              LLVM_PATH = "${lib.getLib llvm}/lib/libLLVM.so.21.1";
            };

            sconsFlags = [ "--jobs=$NIX_BUILD_CORES" ];

            buildPhase = ''
              # TODO: should be fixed in ./panda/SConscript but I don't want to mess
              # with submodules
              mkdir -p panda/board/obj
              ${makeHome}
              scons ${builtins.concatStringsSep " " finalAttrs.sconsFlags}
            '';

            installPhase = ''
              mkdir -p ${sitePackages}
              cp -aLR ${builtins.concatStringsSep " " packages} ${sitePackages}
              cat <<EOF | ${python.interpreter}
              import build
              builder = build.ProjectBuilder(".")
              builder.prepare("wheel", "${sitePackages}")
              EOF
            '';

            # so the imports check uses built packages
            preDist = "PYTHONPATH=${sitePackages}:$PYTHONPATH";

            pythonImportsCheck = packages;

          }
        )
      );

    in
    pkg.overrideAttrs pkg.passthru.env;

  # separate package for tests so it can be hacked on without rebuilding the c++ and
  # cython parts
  test =
    (python.pkgs.buildPythonPackage {

      # FIXME: build in sandbox
      #  * system/updated/tests/test_base.py::TestBaseUpdate::setup_method uses sudo
      #    to mount self.tmpdir as tmpfs which don't work in the nix sandbox
      #  * tools/lib/tests/test_caching.py::TestFileDownload requires net
      #  * TODO: get a list of all tests requiring net
      __noChroot = true;

      pname = pkg.pname + "-test";
      inherit (pkg) version;

      pyproject = false;
      dontPatch = true;
      dontConfigure = true;
      dontBuild = true;
      dontInstall = true;
      enableParallelBuilding = true;

      COMMA_CACHE = "/var/tmp/comma-cache";

      # do not filter source as it will make an extra copy to the store
      inherit (pkg) src;

      # override hypothesis and pytest-xdist with local versions, not overriding in
      # the overlay as this would cause a mass rebuild
      # BUG: version constraints in optional-dependencies are not enforced in nixpkgs
      nativeCheckInputs = [
        pkg
        cacert
        ffmpeg
        gitMinimal
        rsync
        sudo
      ]
      ++ (builtins.filter (
        pkg: pkg.pname != "hypothesis" && pkg.pname != "pytest-xdist"
      ) pyAttrs.optional-dependencies.testing)
      ++ pyAttrs.optional-dependencies.docs
      ++ (with python.pkgs; [
        hypothesis-local
        pytestCheckHook
        pytest-xdist-local
      ]);

      preCheck = ''
        ${makeHome}
        # remove the local (unbuilt) packages which shadow the built package on sys.path
        rm -rf ${builtins.concatStringsSep " " packages}
        rsync -r ${pkg}/${python.sitePackages}/openpilot/system/ system/ || true
      '';

    }).overrideAttrs
      (pkg: {
        nativeBuildInputs = builtins.filter (
          pkg: builtins.match "^python-.*-hook.*" pkg.name == null
        ) pkg.nativeBuildInputs;
      });

in

pkg.overrideAttrs (pkg: {
  passthru = pkg.passthru // {
    inherit test;
  };
})
