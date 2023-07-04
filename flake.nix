{
  description = "hasktorch on nixpkgs haskell infrastructure";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";

  inputs.hasktorch.url = github:hasktorch/hasktorch;
  inputs.hasktorch.flake = false; # Otherwise, nix build emits error because "hasktorch/hasktorch/haskell-nix/nix-tools" has a relative path url

  inputs.tokenizers.url = github:hasktorch/tokenizers/9d25f0ba303193e97f8b22b9c93cbc84725886c3;
  inputs.tokenizers.flake = false;

  inputs.typelevel-rewrite-rules.url = github:hasktorch/typelevel-rewrite-rules/4176e10d4de2d1310506c0fcf6a74956d81d59b6;
  inputs.typelevel-rewrite-rules.flake = false;

  inputs.type-errors-pretty.url = github:hasktorch/type-errors-pretty/32d7abec6a21c42a5f960d7f4133d604e8be79ec;
  inputs.type-errors-pretty.flake = false;

  inputs.inline-c.url = github:fpco/inline-c/2d0fe9b2f0aa0e1aefc7bfed95a501e59486afb0;
  inputs.inline-c.flake = false;

  outputs = inputs:

    let

      system = "x86_64-linux";

      inherit (inputs.nixpkgs) lib;

      sources = inputs;

      mk-overlay = import ./mk-overlay { inherit lib sources; };

      hasktorch-configs.cpu     = { profiling = true; cudaSupport = false; cudaMajorVersion = "invalid"; };
      hasktorch-configs.cuda-10 = { profiling = true; cudaSupport = true;  cudaMajorVersion = "10"; };
      hasktorch-configs.cuda-11 = { profiling = true; cudaSupport = true;  cudaMajorVersion = "11"; };

      overlays = __mapAttrs mk-overlay hasktorch-configs;

      overlay = self: super:
        {
          hasktorchPkgs = __mapAttrs (_: super.extend) overlays;
        };

      pkgs = import inputs.nixpkgs { inherit system; overlays = [ overlay ]; };

    in

      {

        inherit mk-overlay pkgs overlay overlays;

        packages.${system}.default =
          let
            ghc-name = "ghc924";
            get-hasktorch = device: pkgs.hasktorchPkgs.${device}.haskell.packages.${ghc-name}.hasktorch;
            devices = __attrNames pkgs.hasktorchPkgs;
          in
            pkgs.linkFarm
              "hasktorch-all"
              (map
                (device: {
                  name = "hasktorch-${device}";
                  path = get-hasktorch device; })
                devices);

      };

}
