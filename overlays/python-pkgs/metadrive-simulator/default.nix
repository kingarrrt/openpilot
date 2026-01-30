{
  buildPythonPackage,
  fetchFromGitHub,
  filelock,
  lxml,
  matplotlib,
  numpy,
  opencv-python-headless,
  pillow,
  progressbar,
  psutil,
  pygments,
  requests,
  setuptools,
  shapely,
  tqdm,
  yapf,
}:

# FIXME: incomplete
buildPythonPackage rec {

  pname = "metadrive-simulator";
  version = "0.4.2.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "commaai";
    repo = "metadrive";
    tag = "MetaDrive-minimal-${version}";
    hash = "sha256-sEZAjvhGxEyxszFSMgURW32ySXRvkznV21j9Df72JH4=";
  };

  build-system = [ setuptools ];

  dependencies = [
    filelock
    # gymnasium>=0.28
    lxml
    matplotlib
    numpy
    opencv-python-headless
    # panda3d-gltf==0.13 # 0.14 will bring some problems
    # panda3d==1.10.14
    pillow
    progressbar
    psutil
    pygments
    requests
    shapely
    tqdm
    tqdm
    yapf
  ];

  pythonImportsCheck = [ "metadrive" ];

}
