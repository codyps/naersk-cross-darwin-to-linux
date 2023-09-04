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

        crossPkgs = ((import nixpkgs) {
          inherit system;
          crossSystem = {
            config = "x86_64-unknown-linux-gnu";
          };
        });

        toolchain = with fenix.packages.${crossPkgs.stdenv.buildPlatform.system};
          combine [
            minimal.rustc
            minimal.cargo
            targets.${crossPkgs.stdenv.targetPlatform.config}.latest.rust-std
          ];

        naersk' = pkgs.callPackage naersk {
          cargo = toolchain;
          rustc = toolchain;
        };

        rust = crossPkgs.rust;
        lib = pkgs.lib;

        rustTargetPlatform = rust.toRustTarget crossPkgs.stdenv.targetPlatform;
        rustTargetPlatformUpper = lib.toUpper (
          builtins.replaceStrings ["-"] ["_"] rustTargetPlatform);
        targetCc = "${crossPkgs.stdenv.cc}/bin/${crossPkgs.stdenv.cc.targetPrefix}cc";
      in
      {
        defaultPackage = naersk'.buildPackage
          {
            CARGO_BUILD_TARGET = "${crossPkgs.stdenv.targetPlatform.config}";
            "CC_${rustTargetPlatform}" = "${targetCc}";
            "CARGO_TARGET_${rustTargetPlatformUpper}_LINKER" = "${targetCc}";
            depsBuildBuild = [ crossPkgs.stdenv.cc ];
            src = ./.;
            strictDeps = true;
          };

        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
