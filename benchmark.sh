#!/usr/bin/env bash

set -u

RUNS=3
TESTSIZE="8G"
RUNTIME=45
OUT="benchmark-$(hostname)-$(date +%Y%m%d-%H%M%S)"
FIOFILE="$HOME/fio-benchmark.bin"

mkdir -p "$OUT"

exec > >(tee "$OUT/console.log") 2>&1

echo "===================================================="
echo " TICSS - HYPERVISOR BENCHMARK"
echo " PVE vs VMware ESXi"
echo "===================================================="
echo
echo "Host: $(hostname)"
echo "Date: $(date --iso-8601=seconds)"
echo

echo "========== SYSTEM =========="
uname -a
echo
lscpu
echo
free -h
echo
lsblk
echo

echo "========== VERSIONS =========="
sysbench --version
fio --version
echo

echo "===================================================="
echo " CPU BENCHMARK"
echo "===================================================="

for RUN in $(seq 1 $RUNS); do

    echo
    echo "---- CPU SINGLE THREAD - RUN $RUN/$RUNS ----"

    sysbench cpu \
        --threads=1 \
        --cpu-max-prime=20000 \
        --time=60 run \
        | tee "$OUT/cpu-1t-run${RUN}.txt"

    sleep 10

    echo
    echo "---- CPU 8 THREADS - RUN $RUN/$RUNS ----"

    sysbench cpu \
        --threads=8 \
        --cpu-max-prime=20000 \
        --time=60 run \
        | tee "$OUT/cpu-8t-run${RUN}.txt"

    sleep 10
done


echo
echo "===================================================="
echo " MEMORY BENCHMARK"
echo "===================================================="

for RUN in $(seq 1 $RUNS); do

    echo
    echo "---- MEMORY READ - RUN $RUN/$RUNS ----"

    sysbench memory \
        --threads=8 \
        --memory-oper=read \
        --memory-block-size=1M \
        --memory-total-size=100G run \
        | tee "$OUT/memory-read-run${RUN}.txt"

    sleep 5

    echo
    echo "---- MEMORY WRITE - RUN $RUN/$RUNS ----"

    sysbench memory \
        --threads=8 \
        --memory-oper=write \
        --memory-block-size=1M \
        --memory-total-size=100G run \
        | tee "$OUT/memory-write-run${RUN}.txt"

    sleep 5
done


echo
echo "===================================================="
echo " STORAGE BENCHMARK"
echo "===================================================="

echo
echo "Creating FIO test file..."

fio \
    --name=prepare \
    --filename="$FIOFILE" \
    --size="$TESTSIZE" \
    --rw=write \
    --bs=1M \
    --direct=1 \
    --ioengine=libaio \
    --iodepth=32 \
    --group_reporting

sync
sleep 10


for RUN in $(seq 1 $RUNS); do

    echo
    echo "---- SEQUENTIAL READ - RUN $RUN/$RUNS ----"

    fio \
        --name=seqread \
        --filename="$FIOFILE" \
        --size="$TESTSIZE" \
        --rw=read \
        --bs=1M \
        --direct=1 \
        --ioengine=libaio \
        --iodepth=32 \
        --runtime="$RUNTIME" \
        --time_based \
        --group_reporting \
        | tee "$OUT/fio-seqread-run${RUN}.txt"

    sleep 10


    echo
    echo "---- SEQUENTIAL WRITE - RUN $RUN/$RUNS ----"

    fio \
        --name=seqwrite \
        --filename="$FIOFILE" \
        --size="$TESTSIZE" \
        --rw=write \
        --bs=1M \
        --direct=1 \
        --ioengine=libaio \
        --iodepth=32 \
        --runtime="$RUNTIME" \
        --time_based \
        --group_reporting \
        | tee "$OUT/fio-seqwrite-run${RUN}.txt"

    sleep 10


    echo
    echo "---- RANDOM 4K 70/30 QD1 - RUN $RUN/$RUNS ----"

    fio \
        --name=4k-q1 \
        --filename="$FIOFILE" \
        --size="$TESTSIZE" \
        --rw=randrw \
        --rwmixread=70 \
        --bs=4k \
        --direct=1 \
        --ioengine=libaio \
        --iodepth=1 \
        --runtime="$RUNTIME" \
        --time_based \
        --group_reporting \
        | tee "$OUT/fio-4k-q1-run${RUN}.txt"

    sleep 10


    echo
    echo "---- RANDOM 4K 70/30 QD32 - RUN $RUN/$RUNS ----"

    fio \
        --name=4k-q32 \
        --filename="$FIOFILE" \
        --size="$TESTSIZE" \
        --rw=randrw \
        --rwmixread=70 \
        --bs=4k \
        --direct=1 \
        --ioengine=libaio \
        --iodepth=32 \
        --runtime="$RUNTIME" \
        --time_based \
        --group_reporting \
        | tee "$OUT/fio-4k-q32-run${RUN}.txt"

    sleep 10
done


echo
echo "===================================================="
echo " TEST COMPLETED"
echo "===================================================="

echo "Results directory:"
echo "$OUT"

echo
echo "Removing temporary FIO file..."
rm -f "$FIOFILE"

echo
echo "DONE"
