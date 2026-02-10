{
  buildPythonPackage,
  fetchPypi,
  pytestCheckHook,
  setuptools,
}:

buildPythonPackage (finalAttrs: {

  pname = "crcmod_plus";
  version = "2.3.1";
  pyproject = true;

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-cy/+PDzj75snLhgn2PuJRZDE1v9VPyorQa4w9PlLD10=";
  };

  build-system = [ setuptools ];

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [ "crcmod" ];

})
