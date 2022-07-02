{ lib, stdenv, fetchFromGitHub, pidgin, json-glib, gettext, discount }:
stdenv.mkDerivation rec{
  pname = "purple-mattermost";
  version = "2.1";
  src = fetchFromGitHub {
    owner = "EionRobb";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-f/jQ7MgttYTa+63uxfG0GKjj3Z9FiXIkpkLiMNjWiCM=";
  };

  nativeBuildInputs = [ gettext ];
  buildInputs = [ pidgin json-glib discount ];

  PKG_CONFIG_PURPLE_PLUGINDIR = "${placeholder "out"}/lib/purple-2";
  PKG_CONFIG_PURPLE_DATADIR = "${placeholder "out"}/share";

  meta = with lib; {
    homepage = "https://github.com/EionRobb/purple-mattermost";
    description = "Mattermost plugin for Pidgin";
    license = licenses.gpl3;
    platforms = platforms.all;
    maintainers = with maintainers; [ pasqui23 ];
  };
}
