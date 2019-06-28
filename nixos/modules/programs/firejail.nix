{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.firejail;


in {
  options.programs.firejail = {
    enable = mkEnableOption "firejail";

    wrappedBinaries = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Wrap the binaries in firejail and place them in the global path.
        </para>
        <para>
        You will get file collisions if you put the actual application binary in
        the global environment and applications started via .desktop files are
        not wrapped if they specify the absolute path to the binary.
      '';
    };

    wrappedPackages = mkOption {
      type = with types; listOf package;
      default = [];
      description = ''
        Packages which have their execution wrapped with firejail.
      '';
    };
  };

  config = mkIf cfg.enable {
    security.wrappers.firejail.source = "${lib.getBin pkgs.firejail}/bin/firejail";

    environment.systemPackages =
    let
      wrappedBins = pkgs.stdenv.mkDerivation rec {
        name = "firejail-wrapped-binaries";
        nativeBuildInputs = with pkgs; [ makeWrapper ];
        buildCommand = ''
          mkdir -p $out/bin
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (command: binary: ''
          cat <<_EOF >$out/bin/${command}
          #!${pkgs.stdenv.shell} -e
          /run/wrappers/bin/firejail ${binary} "\$@"
          _EOF
          chmod 0755 $out/bin/${command}
          '') cfg.wrappedBinaries)}
        '';

        wrappedPkgs = with pkgs; runCommand "firejail-wrap-packages" {} ''
          mkdir -p $out/nix/store
          ${string.concatMapStrings (p: ''
            cp ${p} $out
          '') cfg.wrappedPackages}
          ln -s {,$out}${firejail}
          chroot $out firecfg
          rm $out${firejail}
          rm -rf $out/nix/store
        '';
      };
    in
      optional ([]!=cfg.wrappedBinaries) wrappedBins ++
      optional ([]!=cfg.wrappedPackages) wrappedPkgs;
  };

  meta.maintainers = with maintainers; [ peterhoeg ];
}
