{ lib, buildPythonPackage, fetchPypi}:
buildPythonPackage rec {
  pname = "comic-dl";
  version = "2018.01.10";
  src = fetchPypi {
    inherit pname version;
    sha256 = "43c2c9e5e7a16b6c88ba3088a9bfc82f7db8e13378be7c78d6c14a5f8ed05afd";
  };

}
