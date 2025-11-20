# Overalys that can be a dependent package for other nixpkgs
final: prev: {
  bun = prev.bun.overrideAttrs (finalAttrs: previousAttrs: let
    version = "1.3.2";
  in {
    src =
      finalAttrs.passthru.sources.${
        prev.stdenvNoCC.hostPlatform.system
      } or (throw
        "Unsupported system: ${prev.stdenvNoCC.hostPlatform.system}");

    passthru.sources =
      previousAttrs.passthru.sources
      // {
        "x86_64-linux" = prev.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64-baseline.zip";
          hash = "sha256-f/CaSlGeggbWDXt2MHLL82Qvg3BpAWVYbTA/ryFpIXI=";
        };
      };

    meta.platforms = builtins.attrNames finalAttrs.passthru.sources;
  });

  xscreensaver = prev.xscreensaver.overrideAttrs (previousAttrs: {
    patches =
      previousAttrs.patches
      ++ [
        (final.fetchurl {
          url = "https://pt2k.xii.jp/software/anclock/xscreensaver/anclock-2.2.1-for-xscreensaver-6.10.patch.gz";
          hash = "sha256-2DaTO8I1AnHYSxuRcZzRrBmkc8I23anaS3mUSNShGQs=";
        })
      ];
  });
}
