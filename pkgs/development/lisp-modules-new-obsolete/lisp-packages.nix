# TODO:
# - faster build by using lisp with preloaded asdf?
# - dont include java libs unless abcl?
# - dont use build-asdf-system to build lispWithPackages?
# - make the lisp packages overridable? (e.g. buildInputs glibc->musl)
# - build asdf with nix and use that instead of one shipped with impls
#   (e.g. to fix build with clisp - does anyone use clisp?)
# - claspPackages ? (gotta package clasp with nix first)
# - hard one: remove unrelated sources ( of systems not being built)
# - figure out a less awkward way to patch sources
#   (have to build from src directly for SLIME to work, so can't just patch sources in place)

{ pkgs, lib, stdenv, ... }:


let

  inherit (lib)
    length
    filter
    foldl
    unique
    id
    concat
    concatMap
    mutuallyExclusive
    findFirst
    remove
    setAttr
    getAttr
    hasAttr
    attrNames
    attrValues
    filterAttrs
    mapAttrs
    splitString
    concatStringsSep
    concatMapStringsSep
    replaceStrings
    removeSuffix
    hasInfix
    optionalString
    makeBinPath
    makeLibraryPath
    makeSearchPath
    recurseIntoAttrs
    dontRecurseIntoAttrs
  ;

  inherit (builtins)
    head
    tail
    elem
    split
    storeDir;

  # Returns a flattened dependency tree without duplicates
  # This is probably causing performance problems...
  flattenedDeps = lispLibs:
    let
      toSet = list: builtins.listToAttrs (map (d: { name = d.pname; value = d; }) list);
      toList = attrValues;
      walk = acc: node:
        if length node.lispLibs == 0
        then acc
        else builtins.foldl' walk (acc // toSet node.lispLibs) node.lispLibs;
    in toList (walk {} { inherit lispLibs; });

  # Stolen from python-packages.nix
  # Actually no idea how this works
  makeOverridableLispPackage = f: origArgs:
    let
      ff = f origArgs;
      overrideWith = newArgs: origArgs // (if pkgs.lib.isFunction newArgs then newArgs origArgs else newArgs);
    in
      if builtins.isAttrs ff then (ff // {
        overrideLispAttrs = newArgs: makeOverridableLispPackage f (overrideWith newArgs);
      })
      else if builtins.isFunction ff then {
        overrideLispAttrs = newArgs: makeOverridableLispPackage f (overrideWith newArgs);
        __functor = self: ff;
      }
      else ff;

  #
  # Wrapper around stdenv.mkDerivation for building ASDF systems.
  #
  build-asdf-system =
    (makeOverridableLispPackage (
    { pname,
      version,
      src ? null,
      patches ? [],

      # Native libraries, will be appended to the library path
      nativeLibs ? [],

      # Java libraries for ABCL, will be appended to the class path
      javaLibs ? [],

      # Lisp dependencies
      # these should be packages built with `build-asdf-system`
      lispLibs ? [],

      # Lisp command to run buildScript
      lisp,

      # Some libraries have multiple systems under one project, for
      # example, cffi has cffi-grovel, cffi-toolchain etc.  By
      # default, only the `pname` system is build.
      #
      # .asd's not listed in `systems` are removed in
      # installPhase. This prevents asdf from referring to uncompiled
      # systems on run time.
      #
      # Also useful when the pname is differrent than the system name,
      # such as when using reverse domain naming.
      systems ? [ pname ],

      # The .asd files that this package provides
      asds ? systems,

      # Other args to mkDerivation
      ...
    } @ args:

    let

      # A little slow for big dependency graphs.
      # How to make it faster?
      # Maybe do it in the buildScript in Common Lisp or Bash, instead
      # of here with Nix?
      libsFlat = flattenedDeps lispLibs;

    in stdenv.mkDerivation (rec {
      inherit pname version nativeLibs javaLibs lispLibs lisp systems asds;

      # When src is null, we are building a lispWithPackages and only
      # want to make use of the dependency environment variables
      # generated by build-asdf-system
      dontUnpack = src == null;


      # TODO: Do the propagation like for lisp, native and java like this:
      # https://github.com/teu5us/nix-lisp-overlay/blob/e30dafafa5c1b9a5b0ccc9aaaef9d285d9f0c46b/pkgs/development/lisp-modules/setup-hook.sh
      # Then remove the "echo >> nix-drvs" from buildScript

      # Tell asdf where to find system definitions of lisp dependencies.
      #
      # The "//" ending is important as it makes asdf recurse into
      # subdirectories when searching for .asd's. This is to support
      # projects where .asd's aren't in the root directory.
      CL_SOURCE_REGISTRY = makeSearchPath "/" libsFlat;

      # Tell lisp where to find native dependencies
      #
      # Normally generated from lispLibs, but LD_LIBRARY_PATH as a
      # derivation attr itself can be used as an extension point when
      # the libs are not in a '/lib' subdirectory
      LD_LIBRARY_PATH =
        let
          libs = concatMap (x: x.nativeLibs) libsFlat;
          paths = filter (x: x != "") (map (x: x.LD_LIBRARY_PATH) libsFlat);
          path =
            makeLibraryPath libs
            + optionalString (length paths != 0) ":"
            + concatStringsSep ":" paths;
        in concatStringsSep ":" (unique (splitString ":" path));

      # Java libraries For ABCL
      CLASSPATH = makeSearchPath "share/java/*" (concatMap (x: x.javaLibs) libsFlat);

      # Portable script to build the systems.
      #
      # `lisp` must evaluate this file then exit immediately. For
      # example, SBCL's --script flag does just that.
      #
      # NOTE:
      # Every other library worked fine with asdf:compile-system in
      # buildScript.
      #
      # cl-syslog, for some reason, signals that CL-SYSLOG::VALID-SD-ID-P
      # is undefined with compile-system, but works perfectly with
      # load-system. Strange.
      buildScript = pkgs.writeText "build-${pname}.lisp" ''
        (require :asdf)
        (dolist (s '(${concatStringsSep " " systems}))
          (asdf:load-system s))
      '';

      buildPhase = optionalString (src != null) ''
        # In addition to lisp dependencies, make asdf see the .asd's
        # of the systems being built
        #
        # *Append* src since `lispLibs` can provide .asd's that are
        # also in `src` but are not in `systems` (that is, the .asd's
        # that will be deleted in installPhase). We don't want to
        # rebuild them, but to load them from lispLibs.
        #
        # NOTE: It's important to read files from `src` instead of
        # from pwd to get go-to-definition working with SLIME
        export CL_SOURCE_REGISTRY=$CL_SOURCE_REGISTRY:$src//

        # Similiarily for native deps
        export LD_LIBRARY_PATH=${makeLibraryPath nativeLibs}:$LD_LIBRARY_PATH
        export CLASSPATH=${makeSearchPath "share/java/*" javaLibs}:$CLASSPATH

        # Make asdf compile from `src` to pwd and load `lispLibs`
        # from storeDir. Otherwise it could try to recompile lisp deps.
        export ASDF_OUTPUT_TRANSLATIONS="$src:$(pwd):${storeDir}:${storeDir}"

        # track lisp dependencies for graph generation
        # TODO: Do the propagation like for lisp, native and java like this:
        # https://github.com/teu5us/nix-lisp-overlay/blob/e30dafafa5c1b9a5b0ccc9aaaef9d285d9f0c46b/pkgs/development/lisp-modules/setup-hook.sh
        # Then remove the "echo >> nix-drvs" from buildScript
        echo $lispLibs >> __nix-drvs


        # Finally, compile the systems
        ${lisp} $buildScript
      '';

      # Copy compiled files to store
      #
      # Make sure to include '$' in regex to prevent skipping
      # stuff like 'iolib.asdf.asd' for system 'iolib.asd'
      #
      # Same with '/': `local-time.asd` for system `cl-postgres+local-time.asd`
      installPhase =
        let
          mkSystemsRegex = systems:
            concatMapStringsSep "\\|" (replaceStrings ["." "+"] ["[.]" "[+]"]) systems;
        in
      ''
        mkdir -pv $out
        cp -r * $out

        # Remove all .asd files except for those in `systems`.
        find $out -name "*.asd" \
        | grep -v "/\(${mkSystemsRegex systems}\)\.asd$" \
        | xargs rm -fv || true
      '';

      # Not sure if it's needed, but caused problems with SBCL
      # save-lisp-and-die binaries in the past
      dontStrip = true;
      dontFixup = true;

    } // (args // {
      src = if builtins.length (args.patches or []) > 0
            then pkgs.applyPatches { inherit (args) src patches; }
            else args.src;
      patches = [];

      # make sure that propagated build-inputs from lispLibs are propagated
      propagatedBuildInputs = lib.unique
        (builtins.concatLists
          (lib.catAttrs "propagatedBuildInputs"
            (builtins.concatLists [[args] lispLibs nativeLibs javaLibs])));
    }))));

  # Build the set of lisp packages using `lisp`
  # These packages are defined manually for one reason or another:
  # - The library is not in quicklisp
  # - The library that is in quicklisp is broken
  # - Special build procedure such as cl-unicode, asdf
  #
  # These Probably could be done even in ql.nix
  # - Want to pin a specific commit
  # - Want to apply custom patches
  #
  # They can use the auto-imported quicklisp packages as dependencies,
  # but some of those don't work out of the box.
  #
  # E.g if a QL package depends on cl-unicode it won't build out of
  # the box. The dependency has to be rewritten using the manually
  # fixed cl-unicode.
  #
  # This is done by generating a 'fixed' set of Quicklisp packages by
  # calling quicklispPackagesFor with the right `fixup`.
  commonLispPackagesFor = lisp:
    let
      build-asdf-system' = body: build-asdf-system (body // { inherit lisp; });
    in import ./packages.nix {
      inherit pkgs;
      inherit lisp;
      inherit quicklispPackagesFor;
      inherit fixupFor;
      build-asdf-system = build-asdf-system';
    };

  # Build the set of packages imported from quicklisp using `lisp`
  quicklispPackagesFor = { lisp, fixup ? lib.id, build ? build-asdf-system }:
    let
      build-asdf-system' = body: build (body // {
        inherit lisp;
      });
    in import ./ql.nix {
      inherit pkgs;
      inherit fixup;
      build-asdf-system = build-asdf-system';
    };

  # Rewrite deps of pkg to use manually defined packages
  #
  # The purpose of manual packages is to customize one package, but
  # then it has to be propagated everywhere for it to make sense and
  # have consistency in the package tree.
  fixupFor = manualPackages: qlPkg:
    assert (lib.isAttrs qlPkg && !lib.isDerivation qlPkg);
    let
      # Make it possible to reuse generated attrs without recursing into oblivion
      packages = (lib.filterAttrs (n: v: n != qlPkg.pname) manualPackages);
      substituteLib = pkg:
        if lib.hasAttr pkg.pname packages
        then packages.${pkg.pname}
        else pkg;
      pkg = substituteLib qlPkg;
    in pkg // { lispLibs = map substituteLib pkg.lispLibs; };

  makeAttrName = str:
    removeSuffix
      "_"
      (replaceStrings
        ["+" "." "/"]
        ["_plus_" "_dot_" "_slash_"]
        str);

  oldMakeWrapper = pkgs.runCommand "make-wrapper.sh" {} ''
    substitute ${./old-make-wrapper.sh} $out \
      --replace @shell@ ${pkgs.bash}/bin/bash
  '';

  # Creates a lisp wrapper with `packages` installed
  #
  # `packages` is a function that takes `clpkgs` - a set of lisp
  # packages - as argument and returns the list of packages to be
  # installed
  lispWithPackagesInternal = clpkgs: packages:
    # FIXME just use flattenedDeps instead
    (build-asdf-system rec {
      lisp = (head (lib.attrValues clpkgs)).lisp;
      # See dontUnpack in build-asdf-system
      src = null;
      pname = baseNameOf (head (split " " lisp));
      version = "with-packages";
      lispLibs = packages clpkgs;
      systems = [];
    }).overrideAttrs(o: {
      installPhase = ''
        # The recent version of makeWrapper causes breakage. For more info see
        # https://github.com/Uthar/nix-cl/issues/2
        source ${oldMakeWrapper}

        mkdir -pv $out/bin
        makeWrapper \
          ${head (split " " o.lisp)} \
          $out/bin/${baseNameOf (head (split " " o.lisp))} \
          --prefix CL_SOURCE_REGISTRY : "${o.CL_SOURCE_REGISTRY}" \
          --prefix ASDF_OUTPUT_TRANSLATIONS : ${concatStringsSep "::" (flattenedDeps o.lispLibs)}: \
          --prefix LD_LIBRARY_PATH : "${o.LD_LIBRARY_PATH}" \
          --prefix LD_LIBRARY_PATH : "${makeLibraryPath o.nativeLibs}" \
          --prefix CLASSPATH : "${o.CLASSPATH}" \
          --prefix CLASSPATH : "${makeSearchPath "share/java/*" o.javaLibs}" \
          --prefix PATH : "${makeBinPath (o.buildInputs or [])}" \
          --prefix PATH : "${makeBinPath (o.propagatedBuildInputs or [])}"
      '';
    });

  lispWithPackages = lisp:
    let
      packages = lispPackagesFor lisp;
    in lispWithPackagesInternal packages;

  lispPackagesFor = lisp:
    let
      packages = commonLispPackagesFor lisp;
      qlPackages = quicklispPackagesFor {
        inherit lisp;
        fixup = fixupFor packages;
      };
    in qlPackages // packages;

  commonLispPackages = rec {
    inherit
      build-asdf-system
      lispWithPackagesInternal
      lispPackagesFor
      lispWithPackages;

    # TODO: uncomment clasp when clasp 1.0.0 is packaged

    # There's got to be a better way than this...
    # The problem was that with --load everywhere, some
    # implementations didn't exit with 0 on compilation failure
    # Maybe a handler-case in buildScript?
    sbcl  = "${pkgs.sbcl}/bin/sbcl --script";
    ecl   = "${pkgs.ecl}/bin/ecl --shell";
    abcl  = ''${pkgs.abcl}/bin/abcl --batch --eval "(load \"$buildScript\")"'';
    ccl   = ''${pkgs.ccl}/bin/ccl --batch --eval "(load \"$buildScript\")" --'';
    # clasp = ''${pkgs.clasp}/bin/clasp --non-interactive --quit --load'';

    # Manually defined packages shadow the ones imported from quicklisp

    sbclPackages  = recurseIntoAttrs (lispPackagesFor sbcl);
    eclPackages   = dontRecurseIntoAttrs (lispPackagesFor ecl);
    abclPackages  = dontRecurseIntoAttrs (lispPackagesFor abcl);
    cclPackages   = dontRecurseIntoAttrs (lispPackagesFor ccl);
    # claspPackages = lispPackagesFor clasp;

    sbclWithPackages  = lispWithPackages sbcl;
    eclWithPackages   = lispWithPackages ecl;
    abclWithPackages  = lispWithPackages abcl;
    cclWithPackages   = lispWithPackages ccl;
    # claspWithPackages = lispWithPackages clasp;
  };

in commonLispPackages
