{
  buildPythonPackage,
  catch2,
  fetchPypi,
  pytest,
  pytest-mock,
  pytest-xdist,
  pytestCheckHook,
  setuptools-scm,
}:

buildPythonPackage rec {

  pname = "pytest_cpp";
  version = "2.6.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-wvSdPAOFOayEeGqU2FLk9GGcNMlZecK8acILO98FHYU=";
  };

  build-system = [ setuptools-scm ];

  dependencies = [ pytest ];

  nativeCheckInputs = [
    catch2
    pytestCheckHook
    pytest-mock
    pytest-xdist
  ];

  # FIXME: tests broken
  doCheck = false;

  pythonImportsCheck = [ "pytest_cpp" ];

}
