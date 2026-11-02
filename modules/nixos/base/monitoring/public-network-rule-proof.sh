#!/usr/bin/env bash
# Evaluate safe_id and the nft insert argv. Sourced functions only; nft is not run.
set -euo pipefail

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=public-network-rules.sh
source "$here/public-network-rules.sh"

fail() {
  printf 'public-network rule proof failed: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local got="$1" want="$2" label="$3"
  if [ "$got" != "$want" ]; then
    fail "$label: got [$got] want [$want]"
  fi
}

unit=getty@tty1.service
safe=$(safe_id "$unit")
assert_eq "$safe" "getty_40_tty1.service" "safe_id encodes @"
case "$safe" in
  *@*) fail "safe_id left an @ in the counter id" ;;
esac

base=system.slice/$unit
level=2
counter=tx-$safe
comment="pubacct-v1|tx|$level|$unit|4"
assert_eq "$counter" "tx-getty_40_tty1.service" "counter name"

found_base=0
found_counter=0
found_comment=0
while IFS= read -r -d '' arg; do
  [ "$arg" = "\"$base\"" ] && found_base=1
  [ "$arg" = "\"$counter\"" ] && found_counter=1
  [ "$arg" = "\"$comment\"" ] && found_comment=1
done < <(cgroup_insert_argv output "$level" "$base" "$counter" "$comment" 4)

[ "$found_base" -eq 1 ] || fail "cgroup path was not a quoted argv element"
[ "$found_counter" -eq 1 ] || fail "counter name was not a quoted argv element"
[ "$found_comment" -eq 1 ] || fail "comment was not a quoted argv element"

user_safe=$(safe_id 'user@0.service')
assert_eq "$user_safe" "user_40_0.service" "safe_id user@0"

fwd_id=7
fwd_counter=tx-$safe
fwd_comment="pubacct-v1|fwd|tx|4|$unit|$fwd_id"
found_fwd_counter=0
found_fwd_comment=0
found_fwd_id=0
while IFS= read -r -d '' arg; do
  [ "$arg" = "\"$fwd_counter\"" ] && found_fwd_counter=1
  [ "$arg" = "\"$fwd_comment\"" ] && found_fwd_comment=1
  [ "$arg" = "$fwd_id" ] && found_fwd_id=1
done < <(forward_insert_argv "$fwd_id" "$fwd_counter" "$fwd_comment" 4 tx)

[ "$found_fwd_counter" -eq 1 ] || fail "forward counter name was not a quoted argv element"
[ "$found_fwd_comment" -eq 1 ] || fail "forward comment was not a quoted argv element"
[ "$found_fwd_id" -eq 1 ] || fail "forward mark id was not its own argv element"

stamp_if=veth3
stamp_comment="pubacct-v1|mark|$fwd_id|$unit|$stamp_if"
found_if=0
found_stamp_comment=0
while IFS= read -r -d '' arg; do
  [ "$arg" = "\"$stamp_if\"" ] && found_if=1
  [ "$arg" = "\"$stamp_comment\"" ] && found_stamp_comment=1
done < <(mark_stamp_argv "$stamp_if" "$fwd_id" "$stamp_comment")

[ "$found_if" -eq 1 ] || fail "veth name was not a quoted argv element"
[ "$found_stamp_comment" -eq 1 ] || fail "stamp comment was not a quoted argv element"
