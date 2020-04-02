{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.firejail;
  fj=pkgs.firejail;

  wrapPkgs = ''
    pwd | read _oldDir
    for $bin in $out/{,s}bin
    do
      cd $bin

      for $c in *
      do
        readlink $c | read original
        profile="${fj}/etc/firejail/$c.profile"
        if [[ -e "$profile" ]];then
          outc=$out/$bin/$c
          cat <<_EOF >$outc
          #!${pkgs.stdenv.shell} -e

          exec -a "$0" /run/wrappers/bin/firejail $original "\$@"

          _EOF

          chmod 0755 $outc
        fi
      done
    done
    cd $_oldDir
  '';

  wrappedBins = pkgs.stdenv.mkDerivation rec {
    name = "firejail-wrapped-binaries";
    nativeBuildInputs = with pkgs; [ makeWrapper ];
    buildCommand = ''
      mkdir -p $out/bin
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (command: binary: ''
      cat <<_EOF >$out/bin/${command}
      #!${pkgs.stdenv.shell} -e
      exec -a "$0" /run/wrappers/bin/firejail ${binary} "\$@"
      _EOF
      chmod 0755 $out/bin/${command}
      '') cfg.wrappedBinaries)}
    '';
  };

in {
  disabledModules=["programs/firejail.nix"];
  options.programs.firejail = {
    enable = mkEnableOption "firejail";

    wrapAllPackages = mkEnableOption "automatic setup of links and desktop files installed" // {
      default = true;
    };

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
  };

  config = mkIf cfg.enable {
    security.wrappers.firejail.source = "${lib.getBin fj}/bin/firejail";

    environment.systemPackages = [ wrappedBins ] ;

    environment.extraSetup = optionalString cfg.wrapAllPackages wrapPkgs;
  };

  meta.maintainers = with maintainers; [ peterhoeg ];
}
