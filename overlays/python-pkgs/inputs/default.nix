{
  buildPythonPackage,
  fetchPypi,
  pytestCheckHook,
  setuptools,
}:

buildPythonPackage (finalAttrs: {

  pname = "inputs";
  version = "0.5";
  pyproject = true;

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-ox1blqNSXxIy8ya+nnzozK+HPGsfuE2fPJvD15sj6uQ=";
  };

  build-system = [ setuptools ];

  nativeCheckInputs = [ pytestCheckHook ];

  # FIXME: tests broken
  doCheck = false;

  pythonImportsCheck = [ "inputs" ];

})
