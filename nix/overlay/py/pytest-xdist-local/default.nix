{
  lib,
  fetchpatch,
  pytest-xdist,
}:
lib.makeLocal (
  pytest-xdist.overrideAttrs {
    patches = [
      (fetchpatch {
        url = "https:/github.com/pytest-dev/pytest-xdist/pull/1229.patch";
        hash = "sha256-zkUN/gQ5o+4w9yaSl8j1oYqzJ1rITZU/Zm2nqpewNpk=";
      })
    ];
  }
)
