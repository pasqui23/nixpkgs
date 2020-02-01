{ runCommandNoCCLocal , nix , lib } : alts :

assert builtins.length alts > 0;
let

  altsDrv = map (p: p.drvAttrs) alts;

  hash1stFDO = # taking the outputHash from the 1st fixed output drv
    lib.foldl (a: b:
      if  {} == a  &&  b ? outputHash
      then { inherit (b) outputHash outputHashAlgo outputHashMode; }
      else a
    ) {} altsDrv;

in


runCommandNoCCLocal "sources" (hash1stFDO // {
  inputs = map (p: p.drvPath) alts;
  # passing down required env
  impureEnvVars = map (p: p.impureEnvVars or []) altsDrv;
  buildInputs = [ nix ] ;
  requiredSystemFeatures = [ "recursive-nix" ];
})
''
  for drv in $inputs ; do
    
    D=$(nix-store -r $drv) &&
      cp -a $D $out &&
      exit 0 ||
      true # avoid failing the build if the above subsh fails
  done

  echo Every fetcher failed !!! >&2
  exit 1
''

