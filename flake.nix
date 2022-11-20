{
  description = "elm-tailwind-template";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nix-filter.url = "github:numtide/nix-filter";
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    # TODO: Figure out to make CI work with it
    # defaultSystems = nixpkgs.lib.systems.flakeExposed;
    defaultSystems = ["x86_64-linux"];
    perSystem = nixpkgs.lib.genAttrs defaultSystems;
    pkgsFor = system: nixpkgs.legacyPackages.${system};
    formattersFor = system:
      with (pkgsFor system); [
        elmPackages.elm-format
        nodePackages.prettier
        alejandra
        fd
      ];
    mkElmApplication = {
      system,
      name,
      src,
      minify ? true,
      elm-srcs ? ./elm-srcs.nix,
      elm-registry ? ./registry.dat,
      packageJSON ? ./package.json,
      yarnLock ? ./yarn.lock,
      yarnNix ? ./yarn.nix,
    }: let
      pkgs = pkgsFor system;
      mkElmPackage = ((import nix/elm.nix) {inherit pkgs;}).mkElmPackage;
      nix-filter = import inputs.nix-filter;
      compile-elm = mkElmPackage {
        name = "${name}-compile-elm";
        srcs = elm-srcs;
        registryDat = elm-registry;
        src = nix-filter {
          root = src;
          include = [
            "src"
            "elm.json"
          ];
        };
        targets = ["Main"];
        srcdir = "./src";
        outputJavaScript = true;
      };
      copy-elm = pkgs.stdenv.mkDerivation {
        name = "${name}-copy-elm";
        src = nix-filter {
          root = src;
          include = [
            "public"
            "src"
            "package.json"
            "postcss.config.js"
            "tailwind.config.js"
          ];
        };
        buildPhase = ''
          mkdir build
          cp --no-preserve=all $src/package.json $src/postcss.config.js $src/tailwind.config.js build/.
          cp --no-preserve=all -r $src/public build/public
          cp --no-preserve=all -r $src/src build/src
          mkdir -p build/public/assets/js/
          cp ${compile-elm}/Main${
            if minify
            then ".min"
            else ""
          }.js build/public/assets/js/elm.js
        '';
        installPhase = "
            cp -r build $out
          ";
      };
      postcss = pkgs.mkYarnPackage {
        name = "${name}-postcss";
        src = "${copy-elm}";
        inherit packageJSON yarnLock yarnNix;
        doDist = true;
        buildPhase = ''
          yarn --offline postcss public/assets/pcss/styles.pcss -o public/assets/css/styles.css
        '';
      };
    in
      pkgs.stdenv.mkDerivation {
        inherit name;
        src = "${postcss}/tarballs";
        nativeBuildInputs = [pkgs.gnutar];
        buildPhase = ''
          ls -lah $src
          tar zxvf $src/${name}-postcss.tgz
          rm -r package/public/assets/pcss
        '';
        installPhase = ''
          cp -r package/public $out
        '';
      };
    formatCheckFor = system: let
      pkgs = pkgsFor system;
    in
      pkgs.runCommandNoCC "format-check"
      {
        nativeBuildInputs = formattersFor system;
      } ''
        export LC_CTYPE=C.UTF-8
        export LC_ALL=C.UTF-8
        export LANG=C.UTF-8
        cd ${self}
        make formatCheck
        mkdir $out
      '';
  in {
    devShells = perSystem (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        nativeBuildInputs =
          (formattersFor system)
          ++ [
            pkgs.elmPackages.elm
            pkgs.elm2nix
            pkgs.yarn2nix
            pkgs.yarn
          ];
      };
    });
    packages = perSystem (system: rec {
      myElmApp = mkElmApplication {
        inherit system;
        name = "my-elm-app";
        src = ./.;
      };
      default = myElmApp;
    });
    checks = perSystem (system: {
      formatCheck = formatCheckFor system;
    });
    inherit mkElmApplication;
  };
}
