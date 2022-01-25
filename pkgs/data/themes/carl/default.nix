{ lib, stdenvNoCC, fetchFromGitLab }:

stdenvNoCC.mkDerivation rec{
  pname = "Carl";
  version = "unstable-2022-01-06";
  src = fetchFromGitLab {
    repo = pname;
    owner = "jomada";
    rev = "35c06baa5b1c082aaf3b3631ffb12ed74bdf7727";
    hash = "sha256-gVmDzt0juh+5z7O1jwB0iXVISYMSiCACdx8/SVsRU/Q=";
  };

  dontBuild = true;
  installPhase = ''
    rm LICENSE README.md
    mkdir -p $out/share/plasma/desktoptheme
    mv Carl/wallpaper $out/share/wallpapers
    mv Carl $out/share/plasma/desktoptheme
    mv * $out/share
  '';


  meta = with lib; {
    description = "Dark Plasma theme with bluish gradients";
    homepage = "https://gitlab.com/jomada/carl";
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    maintainers = [ maintainers.pasqui23 ];
  };
}
