{
  description = "Rust Flake.";
  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs";
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    flake-utils,
    devshell,
    nixpkgs,
    fenix,
    ...
  }:
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        appName = "my-app";

        utils = import ./nix/utils.nix;
        overlays = [devshell.overlays.default];
        pkgs = import nixpkgs {inherit system overlays;};
        toolchain = with fenix.packages.${system};
          combine [
            stable.cargo
            stable.rust-analyzer
            stable.rustc
            stable.rustfmt
            stable.clippy
            targets.aarch64-apple-darwin.stable.rust-std
            targets.aarch64-unknown-linux-musl.stable.rust-std
            targets.x86_64-apple-darwin.stable.rust-std
            targets.x86_64-unknown-linux-musl.stable.rust-std
          ];

        crossPkgs = target: let
          isCrossCompiling = target != system;
          config = utils.getTarget target;
          tmpPkgs =
            import
            nixpkgs
            {
              inherit overlays system;
              crossSystem =
                if isCrossCompiling || pkgs.stdenv.isLinux
                then {
                  inherit config;
                  rustc = {inherit config;};
                  isStatic = pkgs.stdenv.isLinux;
                }
                else null;
            };

          toolchain = with fenix.packages.${system};
            combine [
              stable.cargo
              stable.rustc
              targets.aarch64-apple-darwin.stable.rust-std
              targets.aarch64-unknown-linux-musl.stable.rust-std
              targets.x86_64-apple-darwin.stable.rust-std
              targets.x86_64-unknown-linux-musl.stable.rust-std
            ];

          callPackage =
            pkgs.lib.callPackageWith
            (tmpPkgs // {inherit config toolchain;});
        in {
          inherit
            callPackage
            ;
          pkgs = tmpPkgs;
        };
      in rec {
        apps = {
          default = {
            type = "app";
            program = "${packages.default}/bin/${appName}";
          };
        };

        packages =
          {
            default = pkgs.callPackage ./nix/install.nix {inherit appName;};
          }
          // nixpkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
            "${appName}-x86_64-linux" = (crossPkgs "x86_64-linux").callPackage ./nix/build.nix {inherit appName;};
            "${appName}-aarch64-linux" = (crossPkgs "aarch64-linux").callPackage ./nix/build.nix {inherit appName;};
          }
          // nixpkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
            "${appName}-aarch64-darwin" = (crossPkgs "aarch64-darwin").callPackage ./nix/build.nix {inherit appName;};
            "${appName}-x86_64-darwin" = (crossPkgs "x86_64-darwin").callPackage ./nix/build.nix {inherit appName;};
          };

        devShells.default = pkgs.devshell.mkShell {
          packages = [toolchain];
          imports = [(pkgs.devshell.importTOML ./devshell.toml)];
          env = [
            {
              name = "RUST_SRC_PATH";
              value = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
            }
          ];
        };

        overlays.default = final: prev: {
          ${appName} = self.packages.${system}.default;
        };

        formatter = pkgs.alejandra;
      }
    );
}
