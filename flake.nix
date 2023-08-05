{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, flake-utils, naersk, nixpkgs, fenix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = ((import nixpkgs) {
          inherit system;
        });

        # "system" according to nixpkgs pkgsCross
        pkgsCrossSys = "gnu64";
        # "triple"/target according to rust/llvm
        crossTriple = "x86_64-unknown-linux-gnu";

        toolchain = with fenix.packages.${system};
          combine [
            minimal.rustc
            minimal.cargo
            targets.${crossTriple}.latest.rust-std
          ];

        naersk' = naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        };

        crossPkgs = pkgs.pkgsCross.${pkgsCrossSys};

        crossCc = crossPkgs.stdenv.cc;
        crossCcBin =
          "${crossCc}/bin/${crossCc.targetPrefix}cc";
      in
      {
        defaultPackage = naersk'.buildPackage
          {
            src = ./.;
            CARGO_BUILD_TARGET = "${crossTriple}";

            #CC_x86_64_unknown_linux_gnu = "${crossCcBin}";
            HOST_CC = "${pkgs.stdenv.cc.nativePrefix}cc";

            CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "${crossCcBin}";
            strictDeps = true;

            depsBuildBuild = [
              crossCc
            ] ++ pkgs.lib.optional pkgs.stdenv.isDarwin (with crossPkgs; [
              pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
              pkgs.iconv
            ]);
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
