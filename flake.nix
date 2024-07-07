{
  description = "Basic devshell flake.";
  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs";
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    flake-utils,
    devshell,
    nixpkgs,
    ...
  }:
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        overlays = [devshell.overlays.default];
        pkgs = import nixpkgs {inherit system overlays;};
      in {
        devShells.default = pkgs.devshell.mkShell {
          imports = [(pkgs.devshell.importTOML ./devshell.toml)];
        };

        formatter = pkgs.alejandra;
      }
    )
    // {
      templates = {
        rust = {
          path = ./rust;
          description = "Rust devshell and build setup.";
        };
      };
    };
}
