#!/bin/sh
# Self-test for ccsrch 1.0.9-fix1 on the target server.
# Builds fake test files (Luhn-valid numbers that belong to no one) in a temporary
# folder, checks the fixed behaviour, prints PASS/FAIL per check and removes everything.
# Touches nothing outside its temporary folder. Usage: sh selftest.sh [path-to-ccsrch]
CC=${1:-/usr/local/bin/ccsrch}
case "$CC" in /*) ;; *) CC="$(pwd)/$CC" ;; esac
V=4539148803436467; M=5512345678901231
T=$(mktemp -d /tmp/ccsrch-selftest.XXXXXX) || exit 3
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1 (expected '$3', got '$2')"; fail=$((fail+1)); fi; }
hits() { if [ -f "$1" ]; then grep -c . "$1"; else echo 0; fi; }
run() { rm -f "$T/o"; $CC "$@" >/dev/null 2>"$T/e"; }

echo "binary:  $CC"
echo "version: $($CC -h 2>&1 | sed -n 2p | cut -d' ' -f1-2)"
echo "host:    $(uname -n) $(uname -m)"

mkdir -p "$T/t1"; echo "x $V y" > "$T/t1/a.txt"
run -m -o "$T/o" "$T/t1";                 check "folder without trailing slash" "$(hits $T/o)" 1

mkdir -p "$T/t2"; ln -s /nonexistent "$T/t2/broken"
i=1; while [ $i -le 20 ]; do echo "x $V y" > "$T/t2/f$i.txt"; i=$((i+1)); done
run -m -o "$T/o" "$T/t2/";                check "20 files after a broken symlink" "$(hits $T/o)" 20

mkdir -p "$T/t3/sub" "$T/t3other"; echo "x $V y" > "$T/t3/sub/a.txt"; echo "x $M y" > "$T/t3other/b.txt"
ln -s .. "$T/t3/sub/loop"; ln -s "$T/t3other" "$T/t3/sub/elsewhere"
run -m -o "$T/o" "$T/t3";                 check "symlinks not followed, no loop" "$(hits $T/o)" 1

mkdir -p "$T/t4"; i=1; while [ $i -le 1500 ]; do echo "line $i" > "$T/t4/n$i.txt"; i=$((i+1)); done; echo "x $M y" > "$T/t4/n1500.txt"
run -m -o "$T/o" "$T"/t4/*.txt;           check "1500 file arguments in one call" "$(hits $T/o)" 1
                                          check "no 'Unable to open' errors" "$(grep -c 'Unable to open' $T/e)" 0

run -m -o "$T/o" "$T/t1/a.txt" /nonexistent/file "$T/t4/n1500.txt"
                                          check "missing argument skipped, run continues" "$(hits $T/o)" 2

mkdir -p "$T/t6"; echo "x $V y" > "$T/t6/xo.txt.bak"; rm -f "$T/t6/o.txt"
(cd "$T/t6" && $CC -m -o o.txt "$T/t6/" >/dev/null 2>&1)
                                          check "file with similar name still scanned" "$(hits $T/t6/o.txt)" 1

mkdir -p "$T/t7"; echo "x $V y" > "$T/t7/a.txt"
$CC -m -o "$T/t7/out.txt" "$T/t7" >/dev/null 2>&1; $CC -m -o "$T/t7/out.txt" "$T/t7" >/dev/null 2>&1
                                          check "own output never scanned" "$(hits $T/t7/out.txt)" 2

mkdir -p "$T/t9"; echo "x $V y" > "$T/t9/app.log"; echo "x $V y" > "$T/t9/app.log.1"; echo "x $V y" | gzip > "$T/t9/app.log.2.gz"
run -m -n .gz,.xz,.bz2,.zst,.zip,.1,.2,.3,.4,.5,.6,.7,.8,.9 -o "$T/o" "$T/t9"
                                          check "rotated and compressed logs skipped" "$(cut -f1 $T/o | sed 's#.*/##')" "app.log"

mkdir -p "$T/t10"; echo "4111111111111111" > "$T/ign.lst"
echo "test 4111111111111111" > "$T/t10/tc.txt"; echo "order 9${V}7" > "$T/t10/long.txt"; echo "card $V" > "$T/t10/real.txt"
run -m -i "$T/ign.lst" -o "$T/o" "$T/t10"
                                          check "test card and longer number not reported" "$(cut -f1 $T/o | sed 's#.*/##')" "real.txt"
                                          check "number masked" "$(cut -f3 $T/o)" "4539******436467"

echo "RESULT: $pass passed, $fail failed"
[ $fail -eq 0 ]
