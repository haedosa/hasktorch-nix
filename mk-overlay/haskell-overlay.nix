{ lib, haskell, linkFarm, hasktorch-config, libtorch, libtorch-libs, stdenv, sources, setup-num-cores }:

let

  overlay = lib.composeManyExtensions [
    overlay-base
    overlay-setup-num-cores
    overlay-flag
  ];

  hlib = haskell.lib.compose;

  inherit (hasktorch-config) cudaSupport cudaMajorVersion;

  inherit (stdenv.hostPlatform) isDarwin;

  mk-flag-opt = flag: pred: if pred then "-f${flag}" else "-f-${flag}";

  overlay-base =
    hself: hsuper:
    (__mapAttrs
      (pname: path: hself.callCabal2nix pname path {})
      {
        tokenizers-haskell      = "${sources.tokenizers}/bindings/haskell/tokenizers-haskell";
        typelevel-rewrite-rules = sources.typelevel-rewrite-rules;
        type-errors-pretty      = sources.type-errors-pretty;
        inline-c                = "${sources.inline-c}/inline-c";
        inline-c-cpp            = "${sources.inline-c}/inline-c-cpp";
        codegen                 = "${sources.hasktorch}/codegen";
        libtorch-ffi-helper     = "${sources.hasktorch}/libtorch-ffi-helper";
        hasktorch               = "${sources.hasktorch}/hasktorch";
        examples                = "${sources.hasktorch}/examples";
        experimental            = "${sources.hasktorch}/experimental";
      })
    //
    {
      libtorch-ffi =
        hself.callCabal2nixWithOptions "libtorch-ffi" "${sources.hasktorch}/libtorch-ffi"
          (__concatStringsSep " " [
            (mk-flag-opt "rocm" false)
            (mk-flag-opt "cuda" cudaSupport)
            (mk-flag-opt "gcc" (!cudaSupport && isDarwin))
          ])
          {
            inherit (libtorch-libs) torch c10 torch_cpu;
            ${if cudaSupport then "torch_cuda" else null} = libtorch-libs.torch_cuda;
          };
    };

  overlay-setup-num-cores = hself: hsuper: {
    codegen      = setup-num-cores hsuper.codegen;
    libtorch-ffi = setup-num-cores hsuper.libtorch-ffi;
    hasktorch    = setup-num-cores hsuper.hasktorch;
  };

  overlay-flag = hself: hsuper: {
    tokenizers   = hlib.appendConfigureFlag "--extra-lib-dirs=${hself.tokenizers-haskell}/lib" hsuper.tokenizers;
    libtorch-ffi =
      hlib.appendConfigureFlags
        [
          "--extra-include-dirs=${libtorch.dev}/include/torch/csrc/api/include"
          "--extra-lib-dirs=${libtorch.out}/lib"
        ]
        hsuper.libtorch-ffi;
  };

in overlay
