{config, lib, ...}:
with lib;
{
  options.environment.shellPackages = mkOption {
    type = with types; listOf packages;
    default = [];
    description = ''
      Packages to be sourced at shell initialization.

      For each package p:
      <ul>
        <li>\${p}/share/shell/interactive.\${sh} is sourced on interactive shell.</li>
        <li>\${p}/share/shell/login.\${sh} is sourced on login shell.</li>
        <li>\${p}/share/shell/prompt.\${sh} is sourced to get the prompt of the shell.</li>
        <li>\${p}/share/shell/all.\${sh} is sourced on every shell.</li>
      </ul>
      Note that each shell has different files,identified by their extension.
    '';
  };
  config = let
    inherit (config.environment) shellPackages;
    inherit (builtins) pathExists;
    source = p: mkIf (pathExists p) "source ${p}";
    mkSh = sh: mkMerge (map (p:{
      interactiveShellInit = source "${p}/share/shell/interactive.${sh}";
      loginShellInit       = source "${p}/share/shell/login.${sh}";
      promptInit           = source "${p}/share/shell/prompt.${sh}";
      shellInit            = source "${p}/share/shell/all.${sh}";
    }) shellPackages);
  in mkIf (shellPackages!=[]) {

    environment.systemPackages = shellPackages;
    environment.pathsToLink = ["share/shell"];

    programs.bash = mkSh "bash";
    programs.fish = mkSh "fish";
    programs.zsh = mkSh "zsh";

  };
}
