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
            server = lib.mkOption {
              type = types.enum ["none" "single-page" "multi-page"];
              default = "none";
              description = "Whether to create a server for this Elm application";
            };
          };
        });
      in {
        options.elmApps = lib.mkOption {
          type = types.attrsOf elmAppSubmodule;
        };

        config = let
          mkServer = name: app: let
            typeSpecificConfig =
              {
                single-page = ''
                  location / {
                      try_files $uri $uri/ $uri.html /index.html;
                  }'';
                multi-page = "";
              }
              .${app.server};
            config = pkgs.writeTextFile {
              name = "elm-app-server-${name}-nginx.conf";
              text = ''
                pid /tmp/nginx.pid;
                daemon off;
                error_log /tmp/error.log;
                events {}
                http {
                    default_type  application/octet-stream;
                    include       ${pkgs.nginx}/conf/mime.types;
                    server {
                        listen 8080;
                        access_log /tmp/access.log;
                        gzip on;
                        gzip_types application/javascript application/json text/css;
                        # where the root here
                        root ${mkPackage name app};
                        # what file to server as index
                        index index.html;
                        ${typeSpecificConfig}
                    }
                }
              '';
            };
          in
            pkgs.writeShellScriptBin "${name}Server" ''
              ${pkgs.nginx}/bin/nginx -c ${config}'';
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
            copy-elm = pkgs.stdenv.mkDerivation {
              name = "${name}-copy-elm";
              src = app.src;
              buildPhase = ''
                cp --no-preserve=all -r $src build
                mkdir -p build/public/assets/js/
                cp ${compile-elm}/Main${
                  if app.minify
                  then ".min"
                  else ""
                }.js build/public/assets/js/elm.js
              '';
              installPhase = ''
                cp -r build $out
              '';
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
            (lib.mapAttrs
              (name: app: mkPackage name app)
              config.elmApps)
            // (lib.mapAttrs'
              (name: app: {
                name = "${name}Server";
                value = mkServer name app;
              })
              (lib.filterAttrs (_: app: app.server != "none") config.elmApps));
        };
      });
  };
}
