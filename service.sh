#!/system/bin/sh

PREF=9000
TABLE=tun0
DOWNSTREAM=br0
LOG=/data/local/tmp/vpn-tun0-rule-fix.log
IP=/system/bin/ip
LAST_STATE=
VPNHOTSPOT_ACTIVE=0

[ -x "$IP" ] || IP=ip

log_msg() {
  echo "$(date '+%F %T') $*" >> "$LOG"
}

rule_exists() {
  "$IP" rule | grep -q "${PREF}:.*lookup ${TABLE}"
}

add_rule() {
  if ! rule_exists; then
    if "$IP" rule add pref "$PREF" lookup "$TABLE"; then
      "$IP" route flush cache
      log_msg "added rule: pref $PREF lookup $TABLE"
    else
      log_msg "failed to add rule: pref $PREF lookup $TABLE"
    fi
  fi
}

start_vpnhotspot() {
  if [ "$VPNHOTSPOT_ACTIVE" -eq 0 ]; then
    if am start-foreground-service \
      -n be.mygod.vpnhotspot/.TetheringService \
      --esa interface.add "$DOWNSTREAM" >/dev/null 2>&1; then
      VPNHOTSPOT_ACTIVE=1
      log_msg "started VPN Hotspot for $DOWNSTREAM"
    else
      log_msg "failed to start VPN Hotspot for $DOWNSTREAM"
    fi
  fi
}

stop_vpnhotspot() {
  if [ "$VPNHOTSPOT_ACTIVE" -eq 1 ]; then
    if am start-foreground-service \
      -n be.mygod.vpnhotspot/.TetheringService \
      --es interface.remove "$DOWNSTREAM" >/dev/null 2>&1; then
      log_msg "stopped VPN Hotspot for $DOWNSTREAM"
    else
      log_msg "failed to stop VPN Hotspot for $DOWNSTREAM"
    fi
    VPNHOTSPOT_ACTIVE=0
  fi
}

delete_rule() {
  while rule_exists; do
    if "$IP" rule del pref "$PREF" lookup "$TABLE"; then
      "$IP" route flush cache
      log_msg "removed rule: pref $PREF lookup $TABLE"
    else
      log_msg "failed to remove rule: pref $PREF lookup $TABLE"
      break
    fi
  done
}

system_ready() {
  [ "$(getprop sys.boot_completed)" = "1" ]
}

tun0_ready() {
  [ -d "/sys/class/net/$TABLE" ] && "$IP" route show table "$TABLE" | grep -q .
}

set_state() {
  if [ "$LAST_STATE" != "$1" ]; then
    LAST_STATE="$1"
    log_msg "$1"
  fi
}

while ! system_ready; do
  sleep 5
done

log_msg "service started"
log_msg "ip command: $IP"

while true; do
  if tun0_ready; then
    set_state "$TABLE ready"
    start_vpnhotspot
    add_rule
  else
    set_state "waiting for $TABLE routes"
    stop_vpnhotspot
    delete_rule
  fi

  sleep 5
done
