{ procps, haskell }:

hpkg:

let

  hlib = haskell.lib.compose;

  libname = hpkg.pname;

  patch-script =
    if libname == "hasktorch"
    then
      ''
        export NIX_BUILD_CORES=$USED_NUM_CPU
        sed -i -e 's/\(^\(.*\)default-extension\)/\2ghc-options: -j'$USED_NUM_CPU' +RTS -A128m -n2m -M'$USED_MEMX2_GB' -RTS\n\1/g' ${libname}.cabal
      ''
    else
      ''
        sed -i -e 's/\(^\(.*\)default-extension\)/\2ghc-options: -j'$USED_NUM_CPU' +RTS -A128m -n2m -M'$USED_MEM_GB' -RTS\n\1/g' ${libname}.cabal
      '';

  preConfigure =
    ''
      case "$(uname)" in
        "Darwin")
            TOTAL_MEM_GB=`${procps}/bin/sysctl hw.physmem | awk '{print int($2/1024/1024/1024)}'`
            NUM_CPU=$(${procps}/bin/sysctl -n hw.ncpu)
          ;;
        "Linux")
            TOTAL_MEM_GB=`grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}'`
            NUM_CPU=$(nproc --all)
          ;;
      esac

      USED_MEM_GB=`echo $TOTAL_MEM_GB | awk '{print int(($1 + 1) / 2)}'`
      USED_NUM_CPU=`echo $NUM_CPU | awk '{print int(($1 + 1) / 2)}'`
      USED_NUM_CPU=`echo $USED_MEM_GB $USED_NUM_CPU | awk '{if($1<x$2) {print $1} else {print $2}}'`
      USED_MEM_GB=`echo $USED_NUM_CPU | awk '{print ($1)"G"}'`
      USED_MEMX2_GB=`echo $USED_NUM_CPU | awk '{print ($1 * 2)"G"}'`

      ${patch-script}
    '';

in

hlib.overrideCabal (drv: { inherit preConfigure; }) hpkg
