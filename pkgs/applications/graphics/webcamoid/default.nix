{stdenv, qmake, fetchFromGitHub
, qtbase
, qtdeclarative
, qtquickcontrols
, qtquickcontrols2
, qtsvg
, ffmpeg
, libpulseaudio
, linuxHeaders
}:stdenv.mkDerivation rec{
  name = "webcamoid-${version}";
  version = "8.1.0";
  src = fetchFromGitHub {
    owner = "webcamoid";
    repo = "webcamoid";
    rev = version;
    sha256 = "1vlga3ssqrqraimb58y4xnb35p10ichrnab8f5rqpyk8661hy9mx";
  };

  nativeBuildInputs = [ qmake ];
  buildInputs = [
    qtbase
    qtdeclarative
    qtquickcontrols
    qtquickcontrols2
    qtsvg
    ffmpeg
    libpulseaudio
    linuxHeaders
  ];
  meta = with stdenv.lib; {
    description="a full featured webcam capture application";
    mantainers = [];
    platforms = platforms.linux;
    license = licenses.gpl3;
  };
}
