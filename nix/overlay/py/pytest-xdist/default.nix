{
  lib,
  fetchpatch,
  pytest-xdist,
}:
lib.makeLocal (
  pytest-xdist.overrideAttrs {
    patches = [
      # TODO: pull request is dead - review current state of play
      (fetchpatch {
        url = "https:/github.com/pytest-dev/pytest-xdist/pull/1229.patch";
        hash = "sha256-zkUN/gQ5o+4w9yaSl8j1oYqzJ1rITZU/Zm2nqpewNpk=";
      })
    ];
  }
)
