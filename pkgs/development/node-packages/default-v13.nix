{ pkgs, nodejs, stdenv }:

let
  nodePackages = import ./composition-v13.nix {
    inherit pkgs nodejs;
    inherit (stdenv.hostPlatform) system;
  };
in
nodePackages // {
  node2nix = nodePackages.node2nix.override {
    buildInputs = [ pkgs.makeWrapper ];
    postInstall = ''
      wrapProgram "$out/bin/node2nix" --prefix PATH : ${stdenv.lib.makeBinPath [ pkgs.nix ]}
    '';
  };
  dat = nodePackages.dat.override {
    buildInputs = [ nodePackages.node-gyp-build pkgs.libtool ];
  };
}
