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

        # "architecture" according to docker
        dockerArch = "amd64";
        # "system" according to nix
        dockerSystem = "x86_64-linux";
        # "system" according to nixpkgs pkgsCross
        dockerCrossSys = "gnu64";
        # "triple"/target according to rust/llvm
        dockerTriple = "x86_64-unknown-linux-gnu";

        toolchain = with fenix.packages.${system};
          combine [
            minimal.rustc
            minimal.cargo
            targets.${dockerTriple}.latest.rust-std
          ];

        naersk' = naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        };

        dockerPkgs = pkgs.pkgsCross.${dockerCrossSys};

        dockerCcDrv = dockerPkgs.stdenv.cc;
        dockerCC =
          let
            cc = dockerCcDrv;
          in
          "${cc}/bin/${cc.targetPrefix}cc";
      in
      {
        defaultPackage = naersk'.buildPackage
          {
            src = ./.;
            CARGO_BUILD_TARGET = "${dockerTriple}";
            # FIXME: setting this to
            # ${pkgs.pkgsCross.gnu64.stdenv.cc}/bin/${cc.targetPrefix}cc while
            # using `depsBuildBuild` that includes a darwin framework (and the
            # cc drv) results in `-iframework` args getting passed to the
            # compiler.

            CC_x86_64_unknown_linux_gnu = "${dockerCC}";
            # FIXME: this is `dockerTriple` dependent
            CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "${dockerCC}";
            strictDeps = true;

            depsBuildBuild = [
              dockerCcDrv
            ] ++ pkgs.lib.optional pkgs.stdenv.isDarwin (with dockerPkgs; [
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
            nixpkgs-fmt
            sccache
            clippy
            rust-analyzer
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
