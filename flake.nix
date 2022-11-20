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
    defaultSystems = nixpkgs.lib.systems.flakeExposed;
    perSystem = nixpkgs.lib.genAttrs defaultSystems;
    pkgsFor = system: nixpkgs.legacyPackages.${system};
    mkElmApplication = {
      system,
      name,
      src,
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
          cp ${compile-elm}/Main.js build/public/assets/js/elm.js
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
  in {
    devShells = perSystem (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = [
          pkgs.elmPackages.elm
          pkgs.elm2nix
          pkgs.yarn2nix
          pkgs.elmPackages.elm-format
          pkgs.yarn
          pkgs.nodePackages.prettier
          pkgs.alejandra
          pkgs.fd
        ];
      };
    });
    packages = perSystem (system: {
      my-elm-app = mkElmApplication {
        inherit system;
        name = "my-elm-app";
        src = ./.;
      };
    });
  };
}
