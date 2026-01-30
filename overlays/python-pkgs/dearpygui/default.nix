{
  buildPythonPackage,
  cmake,
  fetchFromGitHub,
  setuptools,
}:

# FIXME: incomplete
buildPythonPackage (finalAttrs: {

  pname = "dearpygui";
  version = "2.1.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "hoffstadt";
    repo = finalAttrs.pname;
    tag = "v${finalAttrs.version}";
    hash = "sha256-itlZuPI/KbXJlEf9yBAIXT8rB0OqoauhLEAHVXBQ4x4=";
  };

  build-system = [ setuptools ];

  nativeBuildInputs = [ cmake ];

  pythonImportsCheck = [ "dearpygui" ];

})
