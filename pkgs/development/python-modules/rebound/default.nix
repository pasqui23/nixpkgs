{ lib
, buildPythonPackage
, fetchPypi
, beautifulsoup4
, requests
, urllib3
, urwid
, setuptools
}: buildPythonPackage rec {
  pname = "rebound-cli";
  version = "2.0.0";
  src = fetchPypi {
    inherit pname version;
    hash = "sha256-2ULoqizfGmWZ3o8vgbn0oeWFEXxBGvviBqEQ//HSgEY=";
  };
  LC_ALL = "C";
  doCheck = false;
  propagatedBuildInputs = [
    beautifulsoup4
    requests
    urllib3
    urwid
  ];
  meta = with lib; rec {
    homepage = "https://github.com/shobrook/rebound";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
