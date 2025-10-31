{
  description = "Backlog.md - A markdown-based task management CLI tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    bun2nix = {
      url = "github:baileyluTCD/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, bun2nix, }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # pkgs = nixpkgs.legacyPackages.${system};
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              bun = prev.bun.overrideAttrs (finalAttrs: previousAttrs:
                let bunVersion = "1.2.23";
                in {
                  src =
                    finalAttrs.passthru.sources.${prev.stdenvNoCC.hostPlatform.system} or (throw
                      "Unsupported system: ${prev.stdenvNoCC.hostPlatform.system}");

                  passthru = previousAttrs.passthru // {
                    sources = previousAttrs.passthru.sources // {
                      "x86_64-linux" = prev.fetchurl {
                        url =
                          "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/bun-linux-x64-baseline.zip";
                        sha256 = "017f89e19e1b40aa4c11a7cf671d3990cb51cc12288a43473238a019a8cafffc";
                        # hash =
                        #   "sha256-oPlaeSdMBsJSzaq/HQ6HjhXQ0wZ5v2dS4DJuwUEwIyM=";
                      };
                    };
                  };
                });
            })
          ];
        };

        # Read version from package.json
        packageJson = builtins.fromJSON (builtins.readFile ./package.json);
        version = packageJson.version;

        ldLibraryPath = ''
          LD_LIBRARY_PATH=${
            pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]
          }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
        '';

        backlog-md = bun2nix.lib.${system}.mkBunDerivation {
          pname = "backlog-md";
          inherit version;
          src = ./.;
          packageJson = ./package.json;
          bunNix = ./bun.nix;

          nativeBuildInputs = with pkgs; [ bun git rsync ];

          preBuild = ''
            export HOME=$TMPDIR
            export HUSKY=0
            export ${ldLibraryPath}
          '';

          buildPhase = ''
            runHook preBuild

            # Build CSS
            bun run build:css

            # Build the CLI tool with embedded version
            bun build --compile --minify --define "__EMBEDDED_VERSION__=${version}" --outfile=dist/backlog src/cli.ts

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            cp dist/backlog $out/bin/backlog
            chmod +x $out/bin/backlog

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description =
              "A markdown-based task management CLI tool with Kanban board";
            longDescription = ''
              Backlog.md is a command-line tool for managing tasks and projects using markdown files.
              It provides Kanban board visualization, task management, and integrates with Git workflows.
            '';
            homepage = "https://backlog.md";
            changelog = "https://github.com/MrLesk/Backlog.md/releases";
            license = licenses.mit;
            maintainers = let
              mrlesk = {
                name = "MrLesk";
                github = "MrLesk";
                githubId = 181345848;
              };
            in with maintainers; [ anpryl mrlesk ];
            platforms = platforms.all;
            mainProgram = "backlog";
          };
        };
      in {
        packages = {
          default = backlog-md;
          "backlog-md" = backlog-md;
        };

        apps = {
          default = flake-utils.lib.mkApp {
            drv = backlog-md;
            name = "backlog";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [ bun bun2nix.packages.${system}.default ];

          buildInputs = with pkgs; [ bun nodejs_20 git biome ];

          shellHook = ''
            export ${ldLibraryPath}

            echo "Backlog.md development environment"
            echo "Available commands:"
            echo "  bun i          - Install dependencies"
            echo "  bun test       - Run tests"
            echo "  bun run cli    - Run CLI in development mode"
            echo "  bun run build  - Build the CLI tool"
            echo "  bun run check  - Run Biome checks"
          '';
        };
      });
}
