# openpilot nix guide

## Setup

1. Install Nix:

   ```bash
   bash <(curl -L https://nixos.org/nix/install)
   echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
   ```

   Then restart the nix daemon with `sudo systemctl restart nix-daemon.service` on
   Linux/Systemd or `sudo launchctl kickstart -k system/org.nixos.nix-daemon` on Mac.

1. Install [direnv](https://direnv.net) if you don't have it already (optional):

   ```bash
   nix profile add nixpkgs#direnv
   ```

1. Clone openpilot:

   ```
   git clone https://github.com/commaai/openpilot.git
   cd openpilot
   ```

With direnv the dev shell launches automatically, otherwise start it with `nix develop`.

## Build

```bash
nix build
```

This produces a symlink at `./result` pointing to the package in the nix store,
something like `/nix/store/rly87maq6is29dnwz9p05w8lvcrznwa4-python3.12-openpilot-0.1.0`.

### Build Cache

You will want to use the Scons cache, but the Nix (intentionally) makes this difficult.
Nix is designed to be **pure and reproducible**. A package build depends *only* on its
declared inputs (other packages, sources, patches, ...) and environment variables
(CCFLAGS, CXX, ...), and the build takes place in a chrooted sandbox, so the cache is
discarded after the build.

#### Setup

Create the cache and configure the nix daemon to allow access to it from the sandbox:

- Linux/Systemd

  ```bash
  SCONS_CACHE=/var/cache/scons
  echo "$SCONS_CACHE 0775 root nixbld -" | sudo tee /etc/tmpfiles.d/nix-scons-cache.conf
  sudo systemd-tmpfiles --create
  echo "extra-sandbox-paths = $SCONS_CACHE" | sudo tee -a /etc/nix/nix.conf
  sudo systemctl restart nix-daemon.service
  ```

- Mac

  ```bash
  SCONS_CACHE=/var/tmp/scons-cache
  sudo mkdir $SCONS_CACHE
  sudo chgrp nixbld $SCONS_CACHE
  sudo chmod g+w $SCONS_CACHE
  echo "extra-sandbox-paths = $SCONS_CACHE" | sudo tee -a /etc/nix/nix.conf
  sudo launchctl kickstart -k system/org.nixos.nix-daemon
  ```

If you use direnv:

```
echo SCONS_CACHE=$SCONS_CACHE >> .env
```

Otherwise:

```
export SCONS_CACHE
```

#### Usage

Build with the `--impure` flag:

```
nix build --impure
```

If you look at the `./result` symlink you'll see it now points to a different store path
because you've changed the derivation's dependencies.

### Build Sugar

For a nicer build experience there is
[nix-output-monitor](https://github.com/maralorn/nix-output-monitor).

```
nom build --impure
```

## Test

```
nix build .#test && pytest
```

To use the build cache you again need `--impure`:

```
nix build --impure .#test && pytest
```

## Scripts

```
nix develop --command scripts/lint/lint.sh
```

## Flake

Nix flakes are the modern standard for managing Nix projects, providing a hermetic
system where every dependency is explicitly defined and pinned. By using a
[flake.nix](../flake.nix) and a [flake.lock](../flake.lock), all external inputs are
locked to specific Git revisions to ensure bit-for-bit reproducibility. Although
technically "experimental" because their CLI and internal schema are not yet finalized,
flakes have become the de facto standard.

### Updating Inputs

```
nix flake update
```

If there were any updates the [flake.lock](../flake.lock) is modified.

### Exploring the Flake

1. `nix flake show` gives an overview:

   ```bash
   $ nix flake show --all-systems
   git+file:///home/art/wrk/prj/openpilot/dev?submodules=1
   ├───devShells
   │   ├───aarch64-darwin
   │   │   └───default: development environment 'python3.12-openpilot-0.1.0'
   │   ├───aarch64-linux
   │   │   └───default: development environment 'python3.12-openpilot-0.1.0'
   │   ├───x86_64-darwin
   │   │   └───default: development environment 'python3.12-openpilot-0.1.0'
   │   └───x86_64-linux
   │       └───default: development environment 'python3.12-openpilot-0.1.0'
   └───packages
       ├───aarch64-darwin
       │   ├───default: package 'python3.12-openpilot-0.1.0'
       │   ├───saveFromGC: package 'save-from-gc'
       │   └───test: package 'python3.12-openpilot-0.1.0-test'
       ├───aarch64-linux
       │   ├───default: package 'python3.12-openpilot-0.1.0'
       │   ├───saveFromGC: package 'save-from-gc'
       │   └───test: package 'python3.12-openpilot-0.1.0-test'
       ├───x86_64-darwin
       │   ├───default: package 'python3.12-openpilot-0.1.0'
       │   ├───saveFromGC: package 'save-from-gc'
       │   └───test: package 'python3.12-openpilot-0.1.0-test'
       └───x86_64-linux
           ├───default: package 'python3.12-openpilot-0.1.0'
           ├───saveFromGC: package 'save-from-gc'
           └───test: package 'python3.12-openpilot-0.1.0-test'
   ```

1. `nix flake metadata` gives inputs providence:

   ```bash
   $ nix flake metadata
   Resolved URL:  git+file:///home/art/wrk/prj/openpilot/dev
   Path:          /nix/store/h26skb6c4q9sixil0njll87qr61llw1b-source
   Revision:      479de43f02b38fea8f6143eb998086c9436c3bbf-dirty
   Last modified: 2026-02-02 14:50:04
   Inputs:
   ├───cache-nix-action: github:nix-community/cache-nix-action/7df957e333c1e5da7721f60227dbba6d06080569?narHash=sha256-%2BnLCogBb3eXaL/YPigD7TiuHR0HTBdyYzEL16Tc3T1k%3D (2026-01-30 20:38:36)
   ├───flake-utils: github:numtide/flake-utils/11707dc2f618dd54ca8739b309ec4fc024de578b?narHash=sha256-l0KFg5HjrsfsO/JpG%2Br7fRrqm12kzFHyUHqHCVpMMbI%3D (2024-11-13 21:27:16)
   │   └───systems: github:nix-systems/default/da67096a3b9bf56a91d16901293e51ba5b49a27e?narHash=sha256-Vy1rq5AaRuLzOxct8nz4T6wlgyUR7zLU309k9mBC768%3D (2023-04-09 08:27:08)
   ├───nixpkgs: github:nixos/nixpkgs/48698d12cc10555a4f3e3222d9c669b884a49dfe?narHash=sha256-yxgb4AmkVHY5OOBrC79Vv6EVd4QZEotqv%2B6jcvA212M%3D (2026-01-25 08:36:19)
   └───pyproject-nix: github:kingarrrt/pyproject.nix/d054a7a35f4610d55d4d07673827905db1f913ac?narHash=sha256-zJt1TjkvAJEbvLq0lbaOwXwkrbvaEjXzhSBEPuU1W6k%3D (2026-01-26 18:56:45)
   └───nixpkgs follows input 'nixpkgs'
   ```

## Interactive Environment

Nix provides an interactive environment with `nix repl`. Here's an example session:

```bash
$ nix repl
Nix 2.33.1+2
Type :? for help.
Loading installable 'git+file:///home/arthur/wrk/prj/openpilot/dev#'...
Added 2 variables.
devShells, packages
nix-repl> packages
{
  aarch64-darwin = { ... };
  aarch64-linux = { ... };
  x86_64-darwin = { ... };
  x86_64-linux = { ... };
}

nix-repl> packages.x86_64-linux
{
  default = «derivation /nix/store/s6q4rrgp48gfh1vgyagh6z3mz3y121xb-python3.12-openpilot-0.1.0.drv»;
  saveFromGC = «derivation /nix/store/p0q5l0f023bcfhsp8cdxji05jh94hnp5-save-from-gc.drv»;
  test = «derivation /nix/store/gwi2qdzs24n1kc3pm59w38inx290pd2v-pytest.drv»;
}

nix-repl> packages.x86_64-linux.default
«derivation /nix/store/s6q4rrgp48gfh1vgyagh6z3mz3y121xb-python3.12-openpilot-0.1.0.drv»

nix-repl> packages.x86_64-linux.default.nativeBuildInputs
[
  «derivation /nix/store/9ccrr31nallgmlg63w0y2g3h3yl2qbc3-python3-3.12.12.drv»
  «derivation /nix/store/a3hr0mbjvx28hgqcrf8j1459ydy2j4zi-wrap-python-hook.drv»
  «derivation /nix/store/9pai6502a1faqc9a0bfhxdazadbaypjl-ensure-newer-sources-hook.drv»
  «derivation /nix/store/yimicnrx10b91k8isvhbyvkk85yarahl-python-remove-tests-dir-hook.drv»
  «derivation /nix/store/z06ixxi04sj2da41jnc8w81c1hzcmidc-python-catch-conflicts-hook.drv»
  «derivation /nix/store/b5qp8ssfkn40igzy5zpqylsfsk3g2y5z-python-remove-bin-bytecode-hook.drv»
  «derivation /nix/store/dyfhvbcjkz6jw4gyzpjzq594hdmr4d8k-python-imports-check-hook.sh.drv»
  «derivation /nix/store/1rs4x0vadc5a03c48yn7j4xh5q1cxvrz-python-namespaces-hook.sh.drv»
  «derivation /nix/store/ai7ir38gyw6waanxawwkyx3lr8n88f9n-acados-0.2.2.drv»
  «derivation /nix/store/8c73dwg8vfk6ndfis634j1qz5kxa8c4z-blasfeo-0.1.4.2.drv»
  «derivation /nix/store/zffj17iyjgng8zn4bpkjh92kyyggc54f-bzip2-1.0.8.drv»
  «derivation /nix/store/y90kjsdhhfjwbaisanqkfd23iv2w8j72-capnproto-1.2.0.drv»
  «derivation /nix/store/8lx0jrnzwl3mn259fxma50ad7z2q17lq-catch2-2.13.10.drv»
  «derivation /nix/store/a1kpbbk1lnnaw2gl5pffs92hxm54mjpm-curl-8.17.0.drv»
  «derivation /nix/store/qskr264s7xwpp1l3g63543gfh73kn8sp-eigen-3.4.1.drv»
  «derivation /nix/store/l8aad8mkq7wa0h7wd99j3647l15n00jj-ffmpeg-8.0.1.drv»
  «derivation /nix/store/ik9yilzj92ii07rbm301bk57i8bmil42-git-minimal-2.52.0.drv»
  «derivation /nix/store/53rjj24ik2ad5xksyryn2x0bxillb6wl-hpipm-0.1.3-unstable-2025-07-25.drv»
  «derivation /nix/store/mmrbh9293yjp0knrgi7lak0vys0kv8a5-libjpeg-turbo-3.1.3.drv»
  «derivation /nix/store/95k28nijhcg6ylxb6sc2lz2l8ws8pw8i-qtbase-5.15.18.drv»
  «derivation /nix/store/xsacanhaz84vim05qaxr0wnbly5v8k5h-qtcharts-5.15.18.drv»
  «derivation /nix/store/fd5zc3qni43bkgpg2snfikrbjpbhwqmw-qtserialbus-5.15.18.drv»
  «derivation /nix/store/d2c2g2kyhdaymmjha8dxggd7psbkypk0-libusb-1.0.29.drv»
  «derivation /nix/store/9xf4s898f9zyc4rbs6bl0il63jw2sjha-libyuv-1622.drv»
  «derivation /nix/store/43hbdr07iwc5k62rr3x9vd8agak1j1cz-clang-wrapper-21.1.8.drv»
  «derivation /nix/store/jrjxd3sz8dnq2pc6kdny59ildx1jblxk-ncurses-6.6.drv»
  «derivation /nix/store/my38fjc3nrj04vhpi8v2ra382mkv731n-ocl-icd-2.3.4.drv»
  «derivation /nix/store/hzrjihlha8ky9vig4z7w8ny3h513sq17-opencl-headers-2025.07.22.drv»
  «derivation /nix/store/2jbq21bnb2mxaswf0vn7hq0ljq5yjlhq-qpoases-3.2.2.drv»
  «derivation /nix/store/jvfwbwncx29gi0qhkishzcmqring2fsn-raylib-5.5-commaai.drv»
  «derivation /nix/store/p724wz0zd438wm4mw2qakhf7n5mhlp2g-scons-4.10.1.drv»
  «derivation /nix/store/7h2gqkrpmgyk57qi5fc4fqamskcvrl6g-zeromq-4.3.5.drv»
  «derivation /nix/store/293kf2jg77kd7g2zwykccz9lhw11z23d-zstd-1.5.7.drv»
  «derivation /nix/store/ghpj27k87jxmjkl8w3z90m6yvsjxvh58-gcc-arm-embedded-15.2.rel1.drv»
  «derivation /nix/store/86qwshy5s54haw6lqmwllrn0xisknn1l-libglvnd-1.7.0.drv»
  «derivation /nix/store/gjg986z94a5xp00vsay0lq98vqj4srkz-python3.12-build-1.3.0.drv»
  «derivation /nix/store/2ka8nyx7g75qvwrf9qkrs5jc8f9la6i3-python3.12-cython-3.1.6.drv»
  «derivation /nix/store/l94z21zmvl2fd4llgn7bhdgjgrc257dc-python3.12-pycapnp-2.1.0.drv»
  «derivation /nix/store/laabavv3v34ysnjk7wl1fjfk62z4vhcn-python3.12-hatchling-1.28.0.drv»
]
```
