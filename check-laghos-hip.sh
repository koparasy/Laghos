#!/usr/bin/env bash

ml load  cmake/3.29.2
ml load rocm/6.3
ml load rocmcc/6.3.1-cce-18.0.1h-magic

set -e

is_installed=$(command -v "./laghos" >/dev/null 2>&1)
if [[ "$?" == 0 ]]; then
    echo "laghos is installed"
else
    echo "laghos is not installed"
    exit 1
fi

# Before running Laghos (updated based on the compiler used)
MNEME_LIBS="$(pwd)/deps/usr/${SYS_TYPE}/lib64/"
export LD_LIBRARY_PATH=/usr/tce/packages/cce/cce-18.0.1-magic/cce/x86_64/lib/:$MNEME_LIBS:$LD_LIBRARY_PATH

DEVICE="hip"

# From https://github.com/CEED/Laghos?tab=readme-ov-file#verification-of-results
# run 	step 	dt 	e
# 1. 	339 	0.000702 	4.9695537349e+01
# 2. 	1041 	0.000121 	3.3909635545e+03
# 3. 	1154 	0.001655 	4.6303396053e+01
# 4. 	560 	0.002449 	1.3408616722e+02
# 5. 	413 	0.000470 	3.2012077410e+01
# 6. 	2872 	0.000064 	5.6547039096e+01
# 7. 	858 	0.000474 	5.6691500623e+01
# 8. 	776 	0.000045 	4.0982431726e+02
# 9. 	2462 	0.000050 	1.1792848680e+02

declare -a step=(339 1041 1154 560 413 2872 858 776 2462)
declare -a dt=(0.000702 0.000121 0.001655 0.002449 0.000470 0.000064 0.000474 0.000045 0.000050)
declare -a e=(4.9695537349e+01 3.3909635545e+03 4.6303396053e+01 1.3408616722e+02 3.2012077410e+01 5.6547039096e+01 5.6691500623e+01 4.0982431726e+02 1.1792848680e+02)
declare -a command=(
    "./laghos -p 0 -dim 2 -rs 3 -tf 0.75 -pa -d $DEVICE"
    "./laghos -p 0 -dim 3 -rs 1 -tf 0.75 -pa -d $DEVICE"
    "./laghos -p 1 -dim 2 -rs 3 -tf 0.80 -pa -d $DEVICE"
    "./laghos -p 1 -dim 3 -rs 2 -tf 0.60 -pa -d $DEVICE"
    "true"
    "./laghos -p 3 -m data/rectangle01_quad.mesh -rs 2 -tf 3.0 -pa -d $DEVICE"
    "./laghos -p 3 -m data/box01_hex.mesh -rs 1 -tf 5.0 -pa -cgt 1e-12 -d $DEVICE"
    "./laghos -p 4 -m data/square_gresho.mesh -rs 3 -ok 3 -ot 2 -tf 0.62831853 -s 7 -pa -d $DEVICE"
    "./laghos -p 7 -m data/rt2D.mesh -tf 4 -rs 1 -ok 4 -ot 3 -pa -d $DEVICE"
)

echo -e "run\tstep\tdt\t\te"
for i in $(seq 0 8); do
    if [[ "$i" == 4 ]]; then
        # We skip this one as it is not defined without mpi
        echo -e "$((i+1))\t${step[$i]}\t${dt[$i]}\t${e[$i]}\tSKIP\tSKIP"
        continue
    fi

    output=$(${command[$i]} | grep "${step[$i]},")
    test_dt=$(echo $output | awk '{print $8}' | tr -d ',')
    test_e=$(echo $output | awk '{print $11}' | tr -d ',')

    if [[ "$test_dt" == "${dt[$i]}" ]]; then
        valid_dt="PASS"
    else
        valid_dt="FAIL ($test_dt)"
    fi

    if [[ "$test_e" == "${e[$i]}" ]]; then
        valid_e="PASS"
    else
        valid_e="FAIL ($test_e)"
    fi

    echo -e "$((i+1))\t${step[$i]}\t${dt[$i]}\t${e[$i]}\t${valid_dt}\t${valid_e}\t${command[$i]}"
done

echo ""
