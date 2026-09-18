{
  description = "Bend 2 (bendlang/bend), the TypeScript implementation, run on bun";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # Pin bumped by ./update.sh from https://bend-lang.com/dl/latest.json.
  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      version = "2.0.5";
      sha256 = "4db70e77ce1b1027f1d0e15dee025921fa794a9b415add4350ec7c64acf2775b";
      forAll = lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in
    {
      packages = forAll (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        rec {
          bend = pkgs.stdenvNoCC.mkDerivation {
            pname = "bend";
            inherit version;

            # The release tarball named in latest.json, byte-verified by hash.
            src = pkgs.fetchurl {
              url = "https://bend-lang.com/dl/${version}.tar.gz";
              inherit sha256;
            };

            nativeBuildInputs = [ pkgs.makeWrapper ];
            sourceRoot = ".";  # tarball has two top-level dirs: bend2/ and guide/
            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/bend $out/bin
              cp -r . $out/share/bend/
              # An install root the launcher would recognise: current/bend2/main.ts.
              ln -s . $out/share/bend/current
              runHook postInstall
            '';

            # mirrors the launcher's exec: "$BUN" "$B/current/bend2/main.ts" "$@",
            # with BEND_HOME as the install root, telemetry off, and no CC (a gcc
            # $CC is rejected outright by main.ts, which then cannot find clang).
            postFixup = ''
              makeWrapper ${pkgs.bun}/bin/bun $out/bin/bend \
                --add-flags "$out/share/bend/bend2/main.ts" \
                --prefix PATH : ${lib.makeBinPath [ pkgs.bun pkgs.clang ]} \
                --set BEND_HOME "$out/share/bend" \
                --set BEND_NO_TELEMETRY 1 \
                --unset CC
            '';

            meta = {
              description = "Bend 2: a massively parallel, high-level language";
              homepage = "https://bend-lang.com";
              license = lib.licenses.mit;
              mainProgram = "bend";
              platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
            };
          };
          default = bend;
        });

      devShells = forAll (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          default = pkgs.mkShell {
            packages = [ pkgs.bun pkgs.clang ];
          };
        });
    };
}
