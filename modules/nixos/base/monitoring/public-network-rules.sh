#!/usr/bin/env bash
# Shared by the collector and the rule-argument test. No nft calls at source time.

safe_id() {
  local s="$1" i c hex out=""
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [A-Za-z0-9.-])
        out+="$c"
        ;;
      *)
        printf -v hex '%02x' "'$c"
        out+="_${hex}_"
        ;;
    esac
  done
  printf '%s\n' "$out"
}

# NUL-separated argv. Quotes are part of the cgroup, counter, and comment
# arguments because nft lexes the command line again.
cgroup_insert_argv() {
  local chain="$1" level="$2" base="$3" counter="$4" comment="$5" family="$6"
  local -a match=()
  if [ "$chain" = output ] && [ "$family" = 4 ]; then
    match=(oifname @pubacct_uplink ip daddr "!=" @pubacct_private4)
  elif [ "$chain" = output ]; then
    match=(oifname @pubacct_uplink ip6 daddr "!=" @pubacct_private6)
  elif [ "$family" = 4 ]; then
    match=(iifname @pubacct_uplink ip saddr "!=" @pubacct_private4)
  else
    match=(iifname @pubacct_uplink ip6 saddr "!=" @pubacct_private6)
  fi
  printf '%s\0' nft insert rule inet filter "$chain" "${match[@]}" \
    socket cgroupv2 level "$level" "\"$base\"" \
    counter name "\"$counter\"" \
    comment "\"$comment\""
}

# Bridge input cannot name the uplink, and inet forward names the bridge
# rather than the veth. Stamp bits 0-7 of the skb mark on the veth, then
# count in inet forward only when that mark leaves or enters an uplink.
# Those bits are outside the fwmark mask 0xff0000. The same id is copied
# into ct mark so the reply is attributed without a second veth match.
mark_stamp_argv() {
  local ifname="$1" id="$2" comment="$3"
  printf '%s\0' nft insert rule bridge pubacct from_container \
    iifname "\"$ifname\"" \
    meta mark set meta mark and 0xffffff00 or "$id" \
    comment "\"$comment\""
}

forward_insert_argv() {
  local id="$1" counter="$2" comment="$3" family="$4" dir="$5"
  local -a match=()
  if [ "$dir" = tx ] && [ "$family" = 4 ]; then
    match=(meta mark and 0xff == "$id" oifname @pubacct_uplink ip daddr "!=" @pubacct_private4 ct mark set ct mark and 0xffffff00 or "$id")
  elif [ "$dir" = tx ]; then
    match=(meta mark and 0xff == "$id" oifname @pubacct_uplink ip6 daddr "!=" @pubacct_private6 ct mark set ct mark and 0xffffff00 or "$id")
  elif [ "$family" = 4 ]; then
    match=(ct mark and 0xff == "$id" iifname @pubacct_uplink ip saddr "!=" @pubacct_private4)
  else
    match=(ct mark and 0xff == "$id" iifname @pubacct_uplink ip6 saddr "!=" @pubacct_private6)
  fi
  printf '%s\0' nft insert rule inet filter forward "${match[@]}" \
    counter name "\"$counter\"" \
    comment "\"$comment\""
}

apply_argv() {
  local -a argv=()
  local arg
  while IFS= read -r -d '' arg; do
    argv+=("$arg")
  done
  "${argv[@]}"
}
