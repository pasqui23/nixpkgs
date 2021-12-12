{ lib
, stdenv
, fetchFromGitHub
, rustPlatform
, installShellFiles
, libiconv
, libgit2
, pkg-config
, nixosTests
, Security
, Foundation
, Cocoa
}:

rustPlatform.buildRustPackage rec {
  pname = "starship";
  version = "1.7.1";

  src = fetchFromGitHub {
    owner = "starship";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-/vP8q2tWDR8EXDekpcONXIgdzRHh3mZzZGY04wb4aA0=";
  };

  nativeBuildInputs = [ installShellFiles pkg-config ];

  buildInputs = [ libgit2 ] ++ lib.optionals stdenv.isDarwin [ libiconv Security Foundation Cocoa ];

  buildNoDefaultFeatures = true;
  # the "notify" feature is currently broken on darwin
  buildFeatures = if stdenv.isDarwin then [ "battery" ] else [ "default" ];

  shells = ["bash" "fish" "zsh"];
  outputs = ["out"] ++ (map (sh:"interactiveShellInit_${sh}") shells);
  postInstall = lib.concatMapStrings (sh: ''
  
    STARSHIP_CACHE=$TMPDIR $out/bin/starship completions ${sh} > starship.${sh}
    installShellCompletion starship.${sh}
    (
      echo 'if [[ $TERM != "dumb" && (-z $INSIDE_EMACS || $INSIDE_EMACS == "vterm") ]]; then'
      $out/bin/starship init ${sh}
      echo fi
    ) > $interactiveShellInit_${sh}

  '') shells;

  cargoSha256 = "sha256-6y0Du3YGfH+SDbG3NdokJyG+Y1q5cI4UZp6XwFdvYxk=";

  preCheck = ''
    HOME=$TMPDIR
  '';

  passthru.tests = {
    inherit (nixosTests) starship;
  };

  meta = with lib; {
    description = "A minimal, blazing fast, and extremely customizable prompt for any shell";
    homepage = "https://starship.rs";
    license = licenses.isc;
    maintainers = with maintainers; [ bbigras danth davidtwco Br1ght0ne Frostman marsam ];
  };
}
