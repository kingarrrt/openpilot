{ buildPythonPackage, fetchurl }:

buildPythonPackage {

  pname = "comma-car-segments";
  version = "0.1.0";

  format = "wheel";

  src = fetchurl {
    url = "https://huggingface.co/datasets/commaai/commaCarSegments/resolve/main/dist/comma_car_segments-0.1.0-py3-none-any.whl";
    hash = "sha256-bGSDVYzZDT6RUv95MDlLsTZ4p6tQ7yx5YB2BjGYjU1I=";
  };

}
