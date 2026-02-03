{
  buildPythonPackage,
  acados,
  setuptools-scm,
  casadi,
  matplotlib,
  numpy,
  scipy,
}:

buildPythonPackage {

  pname = "acados-template";
  version = "2.3.1";
  pyproject = true;

  # FIXME: casadi is built in a way that doesn't produce dist-info so there is no
  # metadata and the check fails
  dontCheckRuntimeDeps = true;

  src = acados.src + /interfaces/acados_template;

  # causes a SyntaxError, introduced in py36, no longer relevant when our min is py311
  patchPhase = "find -type f -exec sed -i /future_fstrings/d {} \\;";

  build-system = [ setuptools-scm ];

  dependencies = [
    casadi
    matplotlib
    numpy
    scipy
  ];

  # TODO: tests

  pythonImportsCheck = [ "acados_template" ];

}
