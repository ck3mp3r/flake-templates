{
  appName,
  config,
  toolchain,
  pkgs,
}: let
  cargoToml = builtins.fromTOML (builtins.readFile ../Cargo.toml);
in
  (pkgs.makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  })
  .buildRustPackage {
    name = cargoToml.package.name;
    version = cargoToml.package.version;

    src = ../.;

    cargoLock.lockFile = ../Cargo.lock;

    installPhase = ''
      install -m755 -D target/${config}/release/${appName} $out/bin/${appName}
    '';

    meta = {
      description = cargoToml.package.description;
      homepage = cargoToml.package.homepage;
      license = pkgs.lib.licenses.unlicense;
    };
  }
