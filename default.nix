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
  gcc-arm-embedded,
  gitMinimal,
  glibc,
  hpipm,
  libGL,
  libjpeg,
  libsForQt5,
  libusb1,
  libyuv-local,
  llvm,
  llvmPackages,
  makeWrapper,
  ncurses,
  ocl-icd,
  opencl-headers,
  pyproject-nix, # flake input, not part of nixpkgs
  pythonInterpreters,
  qpoases,
  raylib-local,
  xvfb-run,
  zeromq,
  zstd,
}:
let

  # load ./pyproject.toml
  project = pyproject-nix.lib.project.loadPyproject { projectRoot = ./.; };

  # get the best available python within the project.requires-python constraint, and
  # overlay local overrides
  python = builtins.head (
    pyproject-nix.lib.util.filterPythonInterpreters {
      inherit (project) requires-python;
      inherit pythonInterpreters;
    }
  );

  # constituent packages
  packages = [
    "cereal"
    "msgq"
    "opendbc"
    "openpilot"
    "panda"
    "rednose"
    "teleoprtc"
    "tinygrad"
  ];

  # render attribute set, which is passed to buildPythonPackage, this must be done
  # here instead of patching ./pyproject.toml because it is needed while evaluating,
  # when patches are applied as part of building
  # TODO: move to ./pyproject.toml
  pyAttrs =
    let

      pyAttrs = project.renderers.buildPythonPackage {
        inherit python;
        extrasAttrMappings = {
          docs = "nativeCheckInputs";
          testing = "nativeCheckInputs";
        };
      };

      replaceLocal =
        name: local: drvs:
        (builtins.filter (drv: drv.pname != name) drvs) ++ [ local ];

    in
    lib.recursiveUpdate pyAttrs {

      # TODO: these changes (apart from the local overrides to hypothesis and
      # pytest-xdist) should be made in ./pyproject.toml

      build-system =
        pyAttrs.build-system
        ++ (with python.pkgs; [
          cython
          scons
        ]);

      dependencies =
        with python.pkgs;
        replaceLocal "pycapnp" pycapnp-local (
          builtins.filter (
            drv:
            !builtins.elem drv.pname [
              "casadi" # not-required (transitive dependency of acados-template)
              "cython" # move to build-system
              "future-fstrings" # not-required
              "pyopenssl" # relax constraint
              "scons" # move to build-system
              "setuptools" # not-required
            ]
          ) pyAttrs.dependencies
        )
        ++ [
          acados-template
          pyopenssl
        ];

      optional-dependencies = {

        testing =
          (builtins.filter (
            drv:
            !builtins.elem drv.pname [
              # XXX: hypothesis and pytest-xdist dependencies are replaced with
              # "<name>-local" derivations because many python packages depend on them,
              # so overlaying with the unsuffixed name would cause a mass rebuild. This
              # would be necessary if they were runtime dependencies because a python
              # environment can't have multiple versions of a package, but they are not.
              "hypothesis"
              "pytest-xdist"
              "ruff" # move to dev
              "ty" # move to dev
            ]
          ) pyAttrs.optional-dependencies.testing)
          ++ (with python.pkgs; [
            parameterized
            tabulate
            hypothesis-local
            pytest-xdist-local
          ]);

        dev =
          (builtins.filter (
            drv:
            !builtins.elem drv.pname (
              [
                "parameterized" # move to testing
                "tabulate" # move to testing
              ]
              ++ lib.optionals stdenv.hostPlatform.isDarwin [
                # depends on xvfb-run which is not available
                "pyautogui"
                # depends on pymonctl which is marked broken
                "pywinctl"
              ]
            )
          ) pyAttrs.optional-dependencies.dev)
          ++ (with python.pkgs; [
            ruff
            ty
          ]);

      };

    };

  # the output's lib/pythonX.XX/site-packages directory where the package is installed
  sitePackages = "${builtins.placeholder "out"}/${python.sitePackages}";

  # TODO: verify that this is complete
  srcFilter =
    root:
    with lib.fileset;
    toSource {
      inherit root;
      fileset =
        union
          (difference
            (fileFilter (
              file:
              !(
                # by extension
                (builtins.any file.hasExt [
                  # nix expressions affect the build (obviously) but they are evaluated
                  # early and are not needed at this point - if they were not filtered
                  # out then a change to a nix expression file that did not change any
                  # dependencies would still cause a rebuild
                  "nix"
                  "lock"
                ])
                # by prefix
                || (builtins.any (prefix: lib.hasPrefix prefix file.name) [
                  "Dockerfile"
                  "install_"
                  "launch_"
                ])
              )
            ) pyAttrs.src)
            # by path
            (
              unions (
                map (dir: ./${dir}) (
                  [
                    "Jenkinsfile"
                    "docs"
                    "mkdocs.yml"
                    "openpilot/third_party"
                    "release"
                    "scripts"
                  ]
                  ++ map (name: "third_party/${name}") [
                    "acados"
                    "catch2"
                    "libyuv"
                    "opencl"
                    "raylib"
                  ]
                )
                # normally .git is stripped, this is for passthru.ci which uses
                # builtins.path
                ++ [ (maybeMissing ./.git) ]
              )
            )
          )
          # re-include acados layout
          (./third_party/acados/acados_template/acados_layout.json);
    };

in

# https://nixos.org/manual/nixpkgs/stable/#buildpythonpackage-function
python.pkgs.buildPythonPackage (
  drv:
  (lib.recursiveUpdate pyAttrs {

    # from qtbase setupHook, not necessary
    dontPatchMkspecs = true;

    # libsForQt5.qtbase provides wrapQtAppsHook, but is not needed
    dontWrapQtApps = true;

    # as it says
    enableParallelBuilding = true;

    # filter source
    src = srcFilter ./.;

    prePatch = ''
      # verify lfs checkout
      model=selfdrive/modeld/models/driving_policy.onnx
      if [[ ! -f $model ]]; then
        echo "lfs bad checkout: model $model not found"
        exit 1
      fi
      if head -1 $model | grep -q git-lfs; then
        echo "lfs bad checkout: model $model is an lfs pointer"
        exit 1
      fi

      # patchShebangs is noisy
      eval "_$(declare -f patchShebangs)"
      patchShebangs() {
        _patchShebangs "$@" > /dev/null
      }

      # /usr/bin/env is not available in the nix sandbox
      patchShebangs \
        opendbc_repo/opendbc/dbc/generator/*/*.py \
        panda/crypto/sign.py \
        selfdrive/locationd/models/*_kf.py
    '';

    # mods to openpilot as a patch set so as not to mess with existing tools
    patches = [
      ./nix/patches/sconstruct.patch
      ./nix/patches/includes.patch
      ./nix/patches/acados.patch
      ./nix/patches/json11.patch
      ./nix/patches/warnings.patch
    ];

    nativeBuildInputs = [
      acados # selfdrive/controls
      blasfeo # ./selfdrive/controls
      bzip2 # ./selfdrive/pandad
      capnproto # ./cereal
      catch2 # self + msgq_repo
      curl # ./system/loggerd
      eigen # ./rednose_repo
      ffmpeg # ./tools/replay
      # FIXME: ./panda/SConscript tries to get git revision which can't work in
      # a nix build because the .git directory is stripped
      gitMinimal # ./panda
      hpipm # ./selfdrive/controls
      libjpeg # ./system/loggerd
      libsForQt5.qtbase # ./tools/cabana
      libsForQt5.qt5.qtcharts # ./tools/cabana
      libsForQt5.qt5.qtserialbus # ./tools/cabana
      libusb1 # ./selfdrive/panda
      libyuv-local # ./system/loggerd ./tools/replay
      llvmPackages.clang # everything
      ncurses # ./tools/replay
      ocl-icd # ./rednose_repo ./msgq_repo/
      opencl-headers # ./msgq_repo
      qpoases # ./selfdrive/controls
      raylib-local # ./selfdrive/ui
      zeromq # ./common ./msgq_repo
      zstd # ./system/loggerd
      python.pkgs.build # installPhase
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      gcc-arm-embedded # ./panda
      libGL # ./selfdrive/ui
    ];

    nativeCheckInputs = pyAttrs.nativeCheckInputs ++ [
      python.pkgs.pytestCheckHook
    ];

    env =
      with lib;
      {
        ACADOS_SOURCE_DIR = acados;
        ACADOS_TEMPLATE_DIR =
          python.pkgs.acados-template + "/" + python.sitePackages + "/acados_template";
        CPPPATH = makeIncludePath (map getInclude drv.nativeBuildInputs);
        LIBPATH = makeLibraryPath (map getLib drv.nativeBuildInputs);
        GLIBC_TUNABLES = "glibc.rtld.execstack=2";
      }
      // optionalAttrs stdenv.hostPlatform.isLinux {
        # tinygrad
        LIBC_PATH = "${getLib glibc}/lib/libc.so.6";
        LLVM_PATH = "${getLib llvm}/lib/libLLVM.so.21.1";
      }
      // (
        # set SCONS_CACHE from environment
        # NOTE: this is impure, so only works with `nix build --impure`
        let
          SCONS_CACHE = builtins.getEnv "SCONS_CACHE";
        in
        optionalAttrs (SCONS_CACHE != "") { inherit SCONS_CACHE; }
      );

    # HACK: buildPythonPackage.buildPhase uses pypa build to create a wheel,
    # <nixpkgs/pkgs/development/interpreters/python/hooks/pypa-build-hook.sh>,
    # then installPhase uses pypa installer to install it,
    # <nixpkgs/pkgs/development/interpreters/python/hooks/pypa-install-hook.sh>.
    # I'm overriding these steps for performance reasons - verified
    # deterministic with `nix build && nix build --rebuild`
    pyproject = false;

    # ./selfdrive/modeld/SConscript calls tinygrad which uses HOME for a cache
    preBuild = ''
      export HOME=$(mktemp -d)
    '';

    # expose scons flags so they can be overridden
    sconsFlags = [ "--jobs=$NIX_BUILD_CORES" ];

    buildPhase = ''
      runHook preBuild
      scons ${builtins.concatStringsSep " " drv.sconsFlags}
      runHook postBuild
    '';

    # clean what we no longer need
    postBuild = ''
      find . -depth \( \
        -type f \( ${
          lib.concatMapStringsSep " -or " (name: "-name \"${name}\"") (
            [ "SC*" ]
            ++ map (ext: "*.${ext}") [
              # binary/intermediate
              "c++" # generated
              "o"
              "os"
              "a"
              "elf"
              # source
              "c"
              "cc"
              "cpp"
              "h"
              "pyx"
              "pxd"
            ]
          )
        } \) -or -type d -empty \
      \) -delete
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p ${sitePackages}

      # copy packages to site-packages
      cp -aLr ${builtins.concatStringsSep " " packages} ${sitePackages}

      # wanted by a test
      cp RELEASES.md ${sitePackages}/openpilot

      # generate package metadata (dist-info)
      cat <<EOF | python
      import build
      build.ProjectBuilder(".").prepare("wheel", "${sitePackages}")
      EOF

      # compile to pyc, unchecked-hash is fine as the store is immutable, compileall
      # swallows errors so use py_compile on failure
      python -m compileall \
        -j $NIX_BUILD_CORES \
        --invalidation-mode=unchecked-hash \
        ${sitePackages} > /dev/null || {
          echo "Error: compileall failure"
          find ${sitePackages} -name \*.py | xargs python -m py_compile
      }

      runHook postInstall
    '';

    pytestFlags = [ "-v" ];

    disabledTestPaths = [
      # wants sudo
      "system/updated/tests/test_git.py"
      # wants net
      "selfdrive/car/tests/test_car_interfaces.py"
      "selfdrive/car/tests/test_models.py"
      "selfdrive/locationd/test/test_locationd_scenarios.py"
      "system/loggerd/tests/test_loggerd.py"
      "system/loggerd/tests/test_uploader.py"
      "system/webrtc/tests/test_webrtcd.py"
      "tools/lib/tests/test_caching.py"
      "tools/lib/tests/test_logreader.py"
    ];

    pythonImportsCheck = packages;

    passthru = {

      # nix/flakes don't play nice with lfs - it may end up putting a pointer in the
      # store - builtin.path ignores git so the files are copied verbatim
      ci = drv.overrideAttrs { src = builtins.path { path = srcFilter ./.; }; };

      # XXX: test suite doesn't work in the sandbox - this exposes a pytest wrapper so
      # tests can be run outside it
      #  * system/updated/tests/test_base.py::TestBaseUpdate::setup_method uses sudo
      #    to mount self.tmpdir as tmpfs
      #  * tools/lib/tests/test_caching.py::TestFileDownload requires net
      #  * ...others
      test =
        let
          pytest = stdenv.mkDerivation {
            name = drv.name + "-pytest";
            dontUnpack = true;
            dontBuild = true;
            nativeBuildInputs = [ makeWrapper ];
            installPhase = ''
              mkdir -p $out/bin
              makeWrapper ${lib.getExe' python.pkgs.pytest "pytest"} $out/bin/pytest \
                --prefix PATH : ${
                  lib.makeBinPath [
                    cacert
                    ffmpeg
                    gitMinimal
                    llvmPackages.clang
                  ]
                } \
                --prefix PYTHONPATH : ${
                  python.pkgs.makePythonPath (
                    [ drv.finalPackage ]
                    ++ (
                      with pyAttrs; dependencies ++ (with optional-dependencies; testing ++ docs)
                    )
                  )
                } \
                --set NIX_TEST 1 \
                --add-flags --import-mode=importlib \
                --set GLIBC_TUNABLES glibc.rtld.execstack=2
              ln -s ${drv.finalPackage}/lib $out/lib
            '';
            meta.mainProgram = "pytest";
          };
        in
        if stdenv.hostPlatform.isLinux then
          let
            pytestExe = lib.getExe pytest;
          in
          stdenv.mkDerivation {
            name = pytest.name + "-xvfb";
            dontUnpack = true;
            dontBuild = true;
            nativeBuildInputs = [ makeWrapper ];
            installPhase = ''
              mkdir -p $out/bin
              ln -s ${pytestExe} $out/bin/pytest-no-xvfb
              makeWrapper ${lib.getExe xvfb-run} $out/bin/pytest \
                --add-flags "-s '-screen 0 2160x1080x24' -- ${pytestExe}"
              ln -s ${drv.finalPackage}/lib $out/lib
            '';
          }
        else
          pytest;

    };

    meta = with lib; {
      # description from ./pyproject.toml
      homepage = "https://comma.ai/openpilot";
      license = licenses.mit;
    };

  })
)
