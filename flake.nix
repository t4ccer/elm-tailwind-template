{
  description = "elm-tailwind-template";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.pre-commit-hooks-nix.flakeModule

        # If you're using this repo as a flake input,
        # instead use: inputs.elm-template.flakeModule
        ./flake-module.nix
      ];
      systems = ["x86_64-linux"];
      flake = {
        flakeModule = ./flake-module.nix;
      };
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: {
        pre-commit.settings = {
          src = ./.;
          hooks = {
            alejandra.enable = true;
            prettier.enable = true;
            elm-format = {
              enable = true;
              # files = pkgs.lib.mkOverride 1 "src/Main.elm";
            };
          };
        };
        elmApps = {
          testElmApp = {
            src = ./.;
          };
        };
        devShells.default = pkgs.mkShell {
          shellHook = config.pre-commit.installationScript;
          nativeBuildInputs = [
            pkgs.elmPackages.elm
            pkgs.elm2nix
            pkgs.yarn2nix
            pkgs.yarn
          ];
        };
        formatter = pkgs.alejandra;
      };
    };
}
