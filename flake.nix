{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, flake-utils, naersk, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = ((import nixpkgs) {
          inherit system;
        });

        crossPkgs = ((import nixpkgs) {
          inherit system;
          crossSystem = {
            config = crossTriple;
          };
        });

        # "triple"/target according to rust/llvm
        crossTriple = "x86_64-unknown-linux-gnu";

        naersk' = crossPkgs.callPackage naersk {};
      in
      {
        defaultPackage = naersk'.buildPackage
          {
            src = ./.;
          };

        formatter = pkgs.nixpkgs-fmt;

        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            rustc
            cargo
            rustfmt
            sccache
          ] ++ lib.optional stdenv.isDarwin [
            darwin.apple_sdk.frameworks.SystemConfiguration
            iconv
          ];

          RUSTC_WRAPPER = "sccache";
          RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
        };
      }
    );
}
