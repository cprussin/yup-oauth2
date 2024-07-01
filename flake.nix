{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    mkCli.url = "github:cprussin/mkCli";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    mkCli,
    ...
  }: (
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        cargo-with-overlay = _: prev: {
          cargo-with = plugins:
            prev.symlinkJoin {
              name = "cargo-with-plugins";
              paths = [prev.cargo];
              buildInputs = [prev.makeWrapper];
              postBuild = ''
                wrapProgram $out/bin/cargo \
                  --prefix PATH : ${prev.lib.makeBinPath ([prev.cargo] ++ plugins)}
              '';
            };
        };

        cli-overlay = _: prev: {
          cli = prev.lib.mkCli "cli" {
            _noAll = true;

            test = {
              rust = {
                audit = "${pkgs.cargo-with [pkgs.cargo-audit]}/bin/cargo audit";
                check = "${pkgs.cargo}/bin/cargo check";
                format = "${pkgs.cargo-with [pkgs.rustfmt]}/bin/cargo fmt --check";
                unit = "${pkgs.cargo}/bin/cargo test";
                version-check = "${pkgs.cargo-with [pkgs.cargo-outdated]}/bin/cargo outdated";
              };
              nix = {
                flake = "${pkgs.nix}/bin/nix flake check";
                lint = "${pkgs.statix}/bin/statix check .";
                dead-code = "${pkgs.deadnix}/bin/deadnix .";
                format = "${pkgs.alejandra}/bin/alejandra --check .";
              };
            };

            fix = {
              rust = {
                format = "${pkgs.cargo-with [pkgs.rustfmt]}/bin/cargo fmt";
              };
              nix = {
                lint = "${pkgs.statix}/bin/statix fix .";
                dead-code = "${pkgs.deadnix}/bin/deadnix -e .";
                format = "${pkgs.alejandra}/bin/alejandra .";
              };
            };
          };
        };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [cargo-with-overlay mkCli.overlays.default cli-overlay];
          config = {};
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            (pkgs.cargo-with [pkgs.rustfmt pkgs.clippy pkgs.cargo-outdated])
            pkgs.cli
            pkgs.git
            pkgs.openssl
            pkgs.pkg-config
            pkgs.rust-analyzer
            pkgs.rustc
          ];
        };
      }
    )
  );
}
