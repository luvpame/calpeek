{
  description = "calpeek — Mac のカレンダーを一行で覗くステータスバー向け CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        localSystem = {
          inherit system;
          darwinMinVersion = "14.0";
        };
      }));
    in
    {
      packages = forAllSystems (pkgs:
        let
          swiftTriple = "${pkgs.stdenv.hostPlatform.darwinArch}-apple-macosx14.0";
        in
        rec {
        calpeek = pkgs.stdenv.mkDerivation {
          pname = "calpeek";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.swift pkgs.swiftpm ];

          NIX_CC_WRAPPER_SUPPRESS_TARGET_WARNING = "1";

          buildPhase = ''
            runHook preBuild
            swiftBuild() {
              swift build \
                --triple ${swiftTriple} \
                --cache-path "$TMPDIR/swiftpm-cache" \
                --config-path "$TMPDIR/swiftpm-config" \
                --security-path "$TMPDIR/swiftpm-security" \
                --manifest-cache local \
                "$@"
            }
            swiftBuild -c release
            swiftBuild -c release --show-bin-path > .swiftpm-bin-path
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 "$(cat .swiftpm-bin-path)/calpeek" "$out/bin/calpeek"
            runHook postInstall
          '';

          meta = {
            description = "Mac のカレンダーを一行で覗くステータスバー向け CLI";
            homepage = "https://github.com/luvpame/calpeek";
            platforms = nixpkgs.lib.platforms.darwin;
            mainProgram = "calpeek";
          };
        };
        default = calpeek;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.swift pkgs.swiftpm ];
        };
      });
    };
}
