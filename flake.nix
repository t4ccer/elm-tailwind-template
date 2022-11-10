{
  description = "My test elm project";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };
  outputs = inputs @ {nixpkgs, ...}: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      nativeBuildInputs = [
        pkgs.elmPackages.elm
        pkgs.elmPackages.elm-format
        pkgs.yarn
        pkgs.nodePackages.prettier
        pkgs.alejandra
        pkgs.fd
      ];
    };
  };
}
