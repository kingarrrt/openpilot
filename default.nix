{
  # pkgs
  lib,
  stdenv,
  acados,
  blasfeo,
  bzip2,
  cacert,
  capnproto,
  catch2,
  curl,
  ffmpeg,
  glibc,
  gcc-arm-embedded,
  gitMinimal,
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
  qpoases,
  raylib-local,
  xvfb-run,
  zeromq,
  zstd,
  # resolved in ./flake.nix
  # whether to start the build with a pre-built scons cache
  sconsCache ? null,
  nixosTest,
  nixVersions,
  loadPyproject,
  rednose-src,
  opendbc-src,
  opencl-headers,
  eigen,
  msgq-src,
  ocl-icd,
}:
let

  defaultSconsCache = "/tmp/scons_cache";

  inherit
    (loadPyproject {
      src = srcFilter ./.;
      # src = ./.;
      # pyproject.toml is needed at eval time so must be patched early
      patches = [ ./nix/patches/pyproject.patch ];

      build-system = [
        acados # selfdrive/controls
        blasfeo # ./selfdrive/controls
        bzip2 # ./selfdrive/pandad
        capnproto # ./cereal
        catch2 # self
        curl # ./system/loggerd
        eigen # rednose transitive
        ffmpeg # ./tools/replay
        hpipm # ./selfdrive/controls
        libjpeg # ./system/loggerd
        # TODO: split this out into its own build
        libsForQt5.qtbase # ./tools/cabana
        libsForQt5.qt5.qtcharts # ./tools/cabana
        libsForQt5.qt5.qtserialbus # ./tools/cabana
        libusb1 # ./selfdrive/panda
        libyuv-local # ./system/loggerd ./tools/replay
        llvmPackages.clang # everything
        ncurses # ./tools/replay
        ocl-icd # ./selfdrive/modeld
        opencl-headers # ./common
        qpoases # ./selfdrive/controls
        raylib-local # ./selfdrive/ui
        zeromq # ./common
        zstd # ./system/loggerd
        python.pkgs.build # installPhase
        python.pkgs.msgq
        python.pkgs.opendbc
        python.pkgs.panda
        python.pkgs.rednose
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        gcc-arm-embedded # ./panda
        libGL # ./selfdrive/ui
      ];

    })
    pyAttrs
    python
    ;

  # python packages installed to ssitePackages
  packages = [
    "cereal"
    "openpilot"
  ];

  # the output's lib/pythonX.XX/site-packages directory where the package is installed
  sitePackages = "${builtins.placeholder "out"}/${python.sitePackages}";

  # filter source for everything extraneous to the build
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
            ) root)
            # by path
            (
              unions (
                map (dir: ./${dir}) (
                  [
                    ".dockerignore"
                    ".editorconfig"
                    ".envrc"
                    ".gitattributes"
                    ".github"
                    ".vscode"
                    "Jenkinsfile"
                    "docs"
                    "mkdocs.yml"
                    "openpilot/third_party"
                    "release"
                    "scripts"
                    # XXX: need all of tools?
                    "uv.lock"
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
  finalAttrs:
  (lib.deepMergePythonAttrs pyAttrs {

    outputs = [
      "out"
      "sconsCache"
    ];

    # from qtbase setupHook, not necessary
    dontPatchMkspecs = true;

    # libsForQt5.qtbase provides wrapQtAppsHook, but is not needed
    dontWrapQtApps = true;

    # as it says
    enableParallelBuilding = true;

    # filter source
    # src = srcFilter pyAttrs.src;

    prePatch = ''
      # verify lfs checkout
      model=selfdrive/modeld/models/driving_policy.onnx
      [[ -f $model ]] || {
        echo "model $model not found"
        exit 1
      }
      if head -1 $model | grep -q git-lfs; then
        echo "model $model is an lfs pointer"
        exit 1
      fi

      # patchShebangs is noisy
      # eval "_$(declare -f patchShebangs)"
      # patchShebangs() {
      #   _patchShebangs "$@" > /dev/null
      # }

      # /usr/bin/env is not available in the nix sandbox
      patchShebangs selfdrive/locationd/models/*_kf.py
    '';

    patches = [
      ./nix/patches/sconstruct.patch
      ./nix/patches/includes.patch
      ./nix/patches/acados.patch
      ./nix/patches/json11.patch
      ./nix/patches/warnings.patch
    ];

    postPatch = ''
      # cp ${rednose-src}/site_scons/site_tools/rednose_filter.py site_scons/site_tools
      ln -sf ${rednose-src} rednose_repo
      ln -sf ${msgq-src} msgq_repo
      ln -sf ${python.pkgs.tinygrad.src} tinygrad_repo
      ln -sf ${python.pkgs.msgq}/${python.sitePackages}/msgq
      cp --remove-destination ${opendbc-src}/opendbc/car/car.capnp cereal
    '';

    env = {
      ACADOS_SOURCE_DIR = acados;
      ACADOS_TEMPLATE_DIR =
        python.pkgs.acados-template + "/" + python.sitePackages + "/acados_template";
      GLIBC_TUNABLES = "glibc.rtld.execstack=2";
    }
    // (
      with lib;
      optionalAttrs stdenv.hostPlatform.isLinux {
        # tinygrad
        LIBC_PATH = "${getLib glibc}/lib/libc.so.6";
        LLVM_PATH = "${getLib llvm}/lib/libLLVM.so.21.1";
      }
    )
    // (
      # set SCONS_CACHE from environment
      # NOTE: this is impure, so only works with `nix build --impure`
      let
        SCONS_CACHE = builtins.getEnv "SCONS_CACHE";
      in
      lib.optionalAttrs (SCONS_CACHE != "") { inherit SCONS_CACHE; }
    );

    # HACK: buildPythonPackage.buildPhase uses pypa build to create a wheel,
    # <nixpkgs/pkgs/development/interpreters/python/hooks/pypa-build-hook.sh>,
    # then installPhase uses pypa installer to install it,
    # <nixpkgs/pkgs/development/interpreters/python/hooks/pypa-install-hook.sh>.
    # I'm overriding these steps for performance reasons - verified
    # deterministic with `nix build && nix build --rebuild`
    pyproject = false;

    # expose scons flags for overriding
    sconsFlags = [ "--jobs=$NIX_BUILD_CORES" ];

    buildPhase = ''

      # setup scons cache
      ${lib.optionalString (sconsCache != null && !finalAttrs ? SCONS_CACHE) ''
        echo "*** using scons cache ${sconsCache}"
        cp -ar ${sconsCache} ${defaultSconsCache}
        chmod -R u+w ${defaultSconsCache}
      ''}

      # tinygrad wants home to write a cache
      export HOME=$(mktemp -d)

      scons ${builtins.concatStringsSep " " finalAttrs.sconsFlags}

      # clean what we no longer need
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

      # keep the scons cache
      cache=''${SCONS_CACHE:-${defaultSconsCache}}
      if [[ -d $cache ]]; then
        echo "*** copying cache to $sconsCache"
        cp -ar $cache $sconsCache
      else
        echo "*** not copying cache"
        echo disabled > $sconsCache
      fi

      runHook postInstall
    '';

    doCheck = false;

    pytestFlags = [
      "-v"
      "--durations=0"
    ]
    ++ (map (test: "--deselect=${test}") [
      "selfdrive/locationd/test/test_paramsd.py::TestParamsd::test_read_saved_params"
      "selfdrive/locationd/test/test_paramsd.py::TestParamsd::test_read_saved_old_format"
      "selfdrive/locationd/test/test_lagd.py::TestLagd::test_read_saved_params"
      "system/manager/test/test_manager.py::TestManager::test_manager_prepare"
      "system/manager/test/test_manager.py::TestManager::test_set_params_with_default_value"
      "system/manager/test/test_manager.py::TestManager::test_duplicate_procs"
    ]);

    disabledTestPaths = [
      "cereal/messaging/tests/test_messaging.py"
      "cereal/messaging/tests/test_pub_sub_master.py"
      "cereal/messaging/tests/test_services.py"
      "system/athena/tests/test_athenad.py"
      "selfdrive/car/tests/test_car_interfaces.py"
      "selfdrive/car/tests/test_cruise_speed.py"
      "selfdrive/car/tests/test_models.py"
      "selfdrive/controls/tests/test_following_distance.py"
      "selfdrive/controls/tests/test_latcontrol.py"
      "selfdrive/controls/tests/test_latcontrol_torque_buffer.py"
      "selfdrive/locationd/test/test_locationd_scenarios.py"
      "selfdrive/test/longitudinal_maneuvers/test_longitudinal.py"
      "selfdrive/test/process_replay/test_fuzzy.py"
      "selfdrive/test/test_onroad.py"
      "selfdrive/ui/tests/test_translations.py"
      "system/hardware/tici/tests/test_power_draw.py"
      "system/loggerd/tests/test_deleter.py"
      "system/loggerd/tests/test_encoder.py"
      "system/loggerd/tests/test_loggerd.py"
      "system/loggerd/tests/test_uploader.py"
      "system/updated/tests/test_git.py"
      "system/webrtc/tests/test_webrtcd.py"
      "tools/lib/tests/test_caching.py"
      "tools/lib/tests/test_logreader.py"
    ];

    pythonImportsCheck = packages;

    passthru = {

      # openpilot-test.nix

      t = nixosTest {
        name = "openpilot-pytest";

        nodes.machine = _: {

          networking = {
            firewall.enable = false;
            nameservers = [
              "1.1.1.1"
              "8.8.8.8"
            ];
          };

          virtualization = {
            memorySize = 1024 * 8;
            diskSize = 1024 * 5;
            # cores = 4;
            useNixStoreImage = true;
          };

          environment.systemPackages = [
            finalAttrs.finalPackage
            cacert
            ffmpeg
            gitMinimal
            llvmPackages.clang
            nixVersions.latest
          ];

        };

        testScript = ''
          start_all()

          machine.wait_for_unit("multi-user.target")
          machine.wait_for_unit("network.target")

          machine.succeed("ping -c 1 1.1.1.1")

          machine.succeed("cp -ar ${finalAttrs.finalPackage} ${finalAttrs.pname}")
          machine.succeed("chmod -R u+w ${finalAttrs.pname}")

          machine.succeed("cd ${finalAttrs.pname} && pytest -v --tb=short")
        '';
      };

      # XXX: test suite doesn't work in the sandbox - this exposes a pytest wrapper so
      # tests can be run outside it
      #  * system/updated/tests/test_base.py::TestBaseUpdate::setup_method uses sudo
      #    to mount self.tmpdir as tmpfs
      #  * tools/lib/tests/test_caching.py::TestFileDownload requires net
      #  * ...others
      test =
        let
          pytest = stdenv.mkDerivation {
            name = finalAttrs.name + "-pytest";
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
                    [ finalAttrs.finalPackage ]
                    ++ (
                      with pyAttrs; dependencies ++ (with optional-dependencies; testing ++ docs)
                    )
                  )
                } \
                --set NIX_TEST 1 \
                --add-flags --import-mode=importlib \
                --set GLIBC_TUNABLES glibc.rtld.execstack=2
              ln -s ${finalAttrs.finalPackage}/lib $out/lib
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
              ln -s ${finalAttrs.finalPackage}/lib $out/lib
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
