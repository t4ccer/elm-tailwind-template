{
  self,
  config,
  lib,
  flake-parts-lib,
  ...
}: let
  inherit
    (flake-parts-lib)
    mkPerSystemOption
    ;
  inherit
    (lib)
    types
    ;
in {
  options = {
    perSystem =
      mkPerSystemOption
      ({
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: let
        elmAppSubmodule = types.submodule (args @ {name, ...}: let
          cfg = config.elmApps.${name};
        in {
          options = {
            src = lib.mkOption {
              type = types.path;
              description = "Source of Elm application";
            };
            minify = lib.mkOption {
              type = types.bool;
              default = true;
              description = "Whether to minify compiled Elm code.";
            };
            elmSrcsFile = lib.mkOption {
              type = types.path;
              default = "${cfg.src}/elm-srcs.nix";
              description = "Path to elm-srcs.nix file.";
            };
            elmRegistryFile = lib.mkOption {
              type = types.path;
              default = "${cfg.src}/registry.dat";
              description = "Path to registry.dat file.";
            };
            packageJsonFile = lib.mkOption {
              type = types.path;
              default = "${cfg.src}/package.json";
              description = "Path to package.json file.";
            };
            yarnLockFile = lib.mkOption {
              type = types.path;
              default = "${cfg.src}/yarn.lock";
              description = "Path to yarn.lock file.";
            };
            yarnNixFile = lib.mkOption {
              type = types.path;
              default = "${cfg.src}/yarn.nix";
              description = "Path to yarn.nix file.";
            };
            runPostCss = lib.mkOption {
              type = types.bool;
              default = true;
              description = "Whether to run `yarn postcss` after Elm compilation";
            };
            postCompilationExtraSteps = lib.mkOption {
              type = types.lines;
              default = "";
              example = "yarn --offline something";
              description = "Extra commands to run after Elm compilation";
            };
          };
        });
      in {
        options.elmApps = lib.mkOption {
          type = types.attrsOf elmAppSubmodule;
        };

        config = let
          mkPackage = name: app: let
            mkElmPackage = ((import nix/elm.nix) {inherit pkgs;}).mkElmPackage;
            compile-elm = mkElmPackage {
              name = "${name}-compile-elm";
              srcs = app.elmSrcsFile;
              registryDat = app.elmRegistryFile;
              src = app.src;
              targets = ["Main"];
              srcdir = "./src";
              outputJavaScript = true;
            };
            copy-elm =
              pkgs.stdenv.mkDerivation {
                name = "${name}-copy-elm";
                src = app.src;
                buildPhase = ''
                  mkdir build
                  cp --no-preserve=all $src/package.json $src/postcss.config.js $src/tailwind.config.js build/.
                  cp --no-preserve=all -r $src/public build/public
                  cp --no-preserve=all -r $src/src build/src
                  mkdir -p build/public/assets/js/
                  cp ${compile-elm}/Main${
                    if app.minify
                    then ".min"
                    else ""
                  }.js build/public/assets/js/elm.js
                '';
                installPhase = "
            cp -r build $out
          ";
              };
            postcomp = pkgs.mkYarnPackage {
              name = "${name}-postcomp";
              src = "${copy-elm}";
              packageJSON = app.packageJsonFile;
              yarnLock = app.yarnLockFile;
              yarnNix = app.yarnNixFile;
              doDist = true;
              buildPhase = ''
                ${
                  if app.runPostCss
                  then "yarn --offline postcss public/assets/pcss/styles.pcss -o public/assets/css/styles.css"
                  else ""
                }
                 ${app.postCompilationExtraSteps}
              '';
            };
          in
            pkgs.stdenv.mkDerivation {
              inherit name;
              src = "${postcomp}/tarballs";
              nativeBuildInputs = [pkgs.gnutar];
              buildPhase = ''
                ls -lah $src
                tar zxvf $src/${name}-postcomp.tgz
                rm -rf package/public/assets/pcss
              '';
              installPhase = ''
                cp -r package/public $out
              '';
            };
        in {
          packages =
            lib.mapAttrs
            (name: app: mkPackage name app)
            config.elmApps;
        };
      });
  };
}
