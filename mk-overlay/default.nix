{ lib, sources }:

device: hasktorch-config:

let

  overlay = lib.composeManyExtensions [
    overlay-base
    overlay-libtorch
    overlay-haskell
  ];

  overlay-base = self: super: {

    inherit sources;

    hasktorch-config = hasktorch-config // { inherit device; };

    setup-num-cores = self.callPackage ./setup-num-cores.nix {};

  };

  overlay-libtorch = self: super: {

    libtorch = self.callPackage "${sources.hasktorch}/nix/libtorch.nix" {
      inherit (self.hasktorch-config) cudaSupport device;
    };

    libtorch-libs = {
      torch     = self.libtorch;
      c10       = self.libtorch;
      torch_cpu = self.libtorch;
      ${if self.hasktorch-config.cudaSupport then "torch_cuda" else null} = self.libtorch;
    };
  };

  overlay-haskell = self: super: {

    hasktorch-haskell-overlay = self.callPackage ./haskell-overlay.nix {};

    haskell = super.haskell // {
      packageOverrides = lib.composeManyExtensions [
        super.haskell.packageOverrides
        self.hasktorch-haskell-overlay ];
    };

  };

in overlay
