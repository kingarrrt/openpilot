{
  # python.pkgs
  buildPyproject,
  # self
  teleoprtc-src,
  # resolved by buildPyproject if not supplied
  pythonInterpreter ? null,
}:
buildPyproject {

  src = teleoprtc-src;
  patch = ./teleoprtc.patch;

  inherit pythonInterpreter;

  # exclude tests that don't work in the sandbox
  pytestFlags =
    map
      (
        test: "--deselect=tests/test_integration.py::TestStreamIntegration::${test}"
      )
      [
        "test_multi_camera_1_camera_and_audio"
        "test_multi_camera_3_camera_and_audio_and_messaging"
        "test_multi_camera_0_multi_camera"
        "test_multi_camera_2_camera_and__messaging"
      ];

}
