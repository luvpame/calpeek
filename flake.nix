{
  description = "calpeek — Mac のカレンダーを一行で覗くステータスバー向け CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        calpeek = pkgs.stdenv.mkDerivation {
          pname = "calpeek";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.swift pkgs.swiftpm ];

          installPhase = ''
            runHook preInstall
            install -Dm755 "$(swiftpmBinPath)/calpeek" "$out/bin/calpeek"
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
