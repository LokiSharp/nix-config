# ================= NixOS related =========================

export def nixos-switch [
    name: string
    mode: string
] {
    if "debug" == $mode {
        # show details via nix-output-monitor
        nom build $".#nixosConfigurations.($name).config.system.build.toplevel" --show-trace --verbose
        nixos-rebuild switch --sudo --flake $".#($name)" --show-trace --verbose
    } else {
        nixos-rebuild switch --sudo --flake $".#($name)"
    }
}

export def nixos-smoke [
    --since: string = "-5 minutes"
] {
    mut failures = 0

    let pass = {|message|
        print $"[PASS] ($message)"
    }
    let info = {|message|
        print $"[INFO] ($message)"
    }
    let have = {|command|
        not (which $command | is-empty)
    }
    let unit_exists = {|unit|
        let result = (systemctl list-unit-files $"($unit).service" --no-legend --no-pager | complete)
        ($result.stdout | str trim) != ""
    }
    let unit_active = {|unit|
        (systemctl is-active --quiet $"($unit).service" | complete).exit_code == 0
    }
    let audit_field = {|status, key|
        let row = (
            $status
            | lines
            | parse "{name} {value}"
            | where name == $key
        )

        if ($row | is-empty) {
            ""
        } else {
            $row.0.value
        }
    }

    if (("/run/current-system" | path exists) and ("/run/booted-system" | path exists)) {
        let current = (readlink -f /run/current-system | str trim)
        let booted = (readlink -f /run/booted-system | str trim)

        if $current == $booted {
            do $pass "current system matches booted system"
        } else {
            print -e "[FAIL] current system differs from booted system"
            $failures = $failures + 1
            do $info $"current: ($current)"
            do $info $"booted:  ($booted)"
        }
    } else {
        do $info "skipping system profile check: /run/current-system or /run/booted-system missing"
    }

    let failed_units = (systemctl --failed --no-legend --no-pager | complete)
    if ($failed_units.stdout | str trim) == "" {
        do $pass "no failed systemd units"
    } else {
        print -e "[FAIL] failed systemd units detected"
        $failures = $failures + 1
        print -e ($failed_units.stdout | str trim)
    }

    if ("/sys/kernel/security/lsm" | path exists) {
        let lsm = (open /sys/kernel/security/lsm | str trim)
        if ($lsm | str contains "apparmor") {
            do $pass "AppArmor LSM enabled"
        } else {
            print -e $"[FAIL] AppArmor LSM missing from /sys/kernel/security/lsm: ($lsm)"
            $failures = $failures + 1
        }
    }

    if (do $have "aa-status") {
        let aa_status = (aa-status | complete)
        if $aa_status.exit_code == 0 {
            do $pass "aa-status healthy"
        } else if (id -u | into int) != 0 {
            do $info "aa-status requires root for full profile details"
        } else {
            print -e "[FAIL] aa-status failed"
            $failures = $failures + 1
            print -e ($aa_status.stderr | str trim)
        }
    } else {
        do $info "aa-status not found"
    }

    let kernel_log = (journalctl -k -b --since $since --no-pager | complete)
    let kernel_errors = (
        $kernel_log.stdout
        | lines
        | where {|line| $line =~ 'apparmor="DENIED"|audit.*error|audit_log_subj_ctx'}
    )
    if ($kernel_errors | is-empty) {
        do $pass $"no AppArmor/audit kernel errors since ($since)"
    } else {
        print -e $"[FAIL] AppArmor/audit kernel errors found since ($since)"
        $failures = $failures + 1
        do $info $"showing first 20 of (($kernel_errors | length)) matching kernel log lines"
        $kernel_errors | first 20 | each {|line| print -e $line }
    }

    if not (do $have "auditctl") {
        do $info "auditctl not found"
    } else {
        let audit_status = (auditctl -s | complete)
        if $audit_status.exit_code != 0 {
            do $info "auditctl -s unavailable; run as root for audit status"
        } else {
            let enabled = (do $audit_field $audit_status.stdout "enabled")
            let lost = (do $audit_field $audit_status.stdout "lost")
            let backlog = (do $audit_field $audit_status.stdout "backlog")

            if $enabled == "1" {
                do $pass "audit enabled"
            } else {
                print -e "[FAIL] audit not enabled"
                $failures = $failures + 1
            }

            if ($lost | default "0") == "0" {
                do $pass "audit lost counter is zero"
            } else {
                print -e $"[FAIL] audit lost counter is ($lost)"
                $failures = $failures + 1
            }

            if ($backlog | default "0") == "0" {
                do $pass "audit backlog is empty"
            } else {
                print -e $"[FAIL] audit backlog is ($backlog)"
                $failures = $failures + 1
            }
        }
    }

    for unit in [
        bind
        bird
        zerotierone
        zerotierone-controller
        tailscaled
        sing-box
        caddy
        gitea
        sftpgo
        grafana
        alertmanager
        victoriametrics
        vmalert
        minio
        postgresql
    ] {
        if not (do $unit_exists $unit) {
            continue
        }

        if not (do $unit_active $unit) {
            do $info $"($unit).service exists but is not active"
            continue
        }

        let pid = (systemctl show $"($unit).service" -p MainPID --value | str trim)
        if ($pid == "" or $pid == "0") {
            do $info $"($unit).service active without MainPID"
            continue
        }

        let label_path = $"/proc/($pid)/attr/apparmor/current"
        if ($label_path | path exists) {
            let label = (open $label_path | str trim)
            print $"[INFO] ($unit).service PID=($pid) AppArmor=($label)"
        } else {
            do $info $"($unit).service PID=($pid) AppArmor label unavailable"
        }
    }

    if ((do $unit_active "bird") and (do $have "birdc")) {
        if (birdc show status | complete).exit_code == 0 {
            do $pass "BIRD control socket responds"
        } else {
            print -e "[FAIL] BIRD control socket check failed"
            $failures = $failures + 1
        }
    }

    if ((do $unit_active "zerotierone") and (do $have "zerotier-cli")) {
        if (zerotier-cli info | complete).exit_code == 0 {
            do $pass "ZeroTier CLI responds"
        } else {
            print -e "[FAIL] ZeroTier CLI check failed"
            $failures = $failures + 1
        }
    }

    if ((do $unit_active "tailscaled") and (do $have "tailscale")) {
        if (tailscale status --peers=false | complete).exit_code == 0 {
            do $pass "Tailscale CLI responds"
        } else {
            print -e "[FAIL] Tailscale CLI check failed"
            $failures = $failures + 1
        }
    }

    if $failures == 0 {
        do $pass "smoke checks passed"
    } else {
        print -e $"[FAIL] ($failures) smoke check\(s\) failed"
        exit $failures
    }
}

export def public-exposure [
    --full
    --min-rate: int = 3000
] {
    if (which nmap | is-empty) {
        print -e "[FAIL] nmap not found"
        exit 1
    }

    mut failures = 0
    let watched_tcp_ports = [
        22
        53
        80
        179
        443
        9100
        9993
        10000
        41641
    ]
    let scan_type = if (id -u | into int) == 0 { "-sS" } else { "-sT" }

    let targets_result = (nix eval .#publicNixosHosts --json --show-trace | complete)
    if $targets_result.exit_code != 0 {
        print -e "[FAIL] failed to evaluate .#publicNixosHosts"
        print -e ($targets_result.stderr | str trim)
        exit 1
    }

    let targets = ($targets_result.stdout | from json)
    if ($targets | is-empty) {
        print -e "[FAIL] no public NixOS hosts found"
        exit 1
    }

    for item in ($targets | transpose name value) {
        let name = $item.name
        let ip = $item.value.ipv4
        let expected_open = ($item.value.expectedOpenTcpPorts | each {|port| $port | into int })
        let expected_set = ($expected_open | each {|port| $port | into string })
        let scan_ports = (
            $watched_tcp_ports
            | append $expected_open
            | uniq
            | sort
            | str join ","
        )

        print $"[INFO] scanning ($name) \(($ip)\), expected open tcp: (($expected_open | sort | str join ', '))"

        let scan = if $full {
            nmap -Pn $scan_type -p- --min-rate ($min_rate | into string) --reason $ip | complete
        } else {
            nmap -Pn $scan_type -p $scan_ports --reason $ip | complete
        }

        if $scan.exit_code != 0 {
            print -e $"[FAIL] nmap scan failed for ($name) \(($ip)\)"
            print -e ($scan.stderr | str trim)
            $failures = $failures + 1
            continue
        }

        let open_ports = (
            $scan.stdout
            | lines
            | parse --regex '^\s*(?P<port>\d+)/tcp\s+(?P<state>\S+)'
            | where state == "open"
            | get port
            | uniq
            | sort
        )

        let unexpected_open = (
            $open_ports
            | where {|port| not ($port in $expected_set)}
        )
        let missing_expected = (
            $expected_set
            | where {|port| not ($port in $open_ports)}
        )

        if ($unexpected_open | is-empty) and ($missing_expected | is-empty) {
            print $"[PASS] ($name) public TCP exposure matches expected ports: (($expected_set | sort | str join ', '))"
        } else {
            print -e $"[FAIL] ($name) public TCP exposure mismatch"
            print -e $"       expected open: (($expected_set | sort | str join ', '))"
            print -e $"       observed open: (($open_ports | sort | str join ', '))"

            if not ($unexpected_open | is-empty) {
                print -e $"       unexpected open: (($unexpected_open | str join ', '))"
            }

            if not ($missing_expected | is-empty) {
                print -e $"       missing expected: (($missing_expected | str join ', '))"
            }

            $failures = $failures + 1
        }
    }

    if $failures == 0 {
        print "[PASS] public exposure checks passed"
    } else {
        print -e $"[FAIL] ($failures) public exposure check\(s\) failed"
        exit $failures
    }
}

# ================= Deployment orchestration =================

# Privileged probes exposed through a Nix-owned sudo wrapper. Keep this
# interface deliberately closed: callers select a fixed action, never a shell
# command or an arbitrary executable.
export def deployment-health-root [
    action: string
    --since-minutes: int = 15
] {
    if (id -u | into int) != 0 {
        print -e "deployment-health-root must run as root"
        exit 1
    }

    match $action {
        "audit-status" => { ^auditctl -s }
        "bird-protocols" => { ^birdc show protocols }
        "journal" => { ^journalctl -b --since $"-($since_minutes) minutes" --priority=0..3 --no-pager }
        "postgresql" => { ^runuser -u postgres -- psql --quiet --tuples-only --command "SELECT 1" postgres }
        "zerotier-status" => { ^zerotier-cli status }
        _ => {
            print -e $"unsupported root health-check action: ($action)"
            exit 2
        }
    }

    if $env.LAST_EXIT_CODE != 0 {
        exit $env.LAST_EXIT_CODE
    }
}

def deployment-inventory [] {
    let metadata_result = (nix eval .#deploymentHostMetadata --json --show-trace | complete)
    if $metadata_result.exit_code != 0 {
        print -e "[FAIL] failed to evaluate .#deploymentHostMetadata"
        print -e ($metadata_result.stderr | str trim)
        exit 1
    }

    let colmena_expression = '{ nodes, lib, ... }: lib.mapAttrs (_: node: { targetHost = node.config.deployment.targetHost; targetPort = node.config.deployment.targetPort; targetUser = node.config.deployment.targetUser; }) nodes'
    # Health checks are read-only and should also work while deployment helpers
    # themselves are being edited in a dirty worktree.
    let targets_result = (colmena eval --impure -E $colmena_expression --show-trace | complete)
    if $targets_result.exit_code != 0 {
        print -e "[FAIL] failed to evaluate Colmena SSH targets"
        print -e ($targets_result.stderr | str trim)
        exit 1
    }

    let metadata = ($metadata_result.stdout | from json)
    let targets = ($targets_result.stdout | from json)

    $metadata
    | transpose name metadata
    | each {|item|
        let target = ($targets | get $item.name)
        $item.metadata | merge {
            targetHost: $target.targetHost
            targetPort: $target.targetPort
            targetUser: $target.targetUser
        }
    }
    | sort-by name
}

def select-deployment-hosts [inventory: list<any>, requested: list<string>] {
    if ($requested | is-empty) {
        return $inventory
    }

    let known = ($inventory | get name)
    let unknown = ($requested | uniq | where {|name| not ($name in $known) })
    if not ($unknown | is-empty) {
        print -e $"[FAIL] unknown deployment host\(s\): (($unknown | str join ', '))"
        print -e $"[INFO] known hosts: (($known | str join ', '))"
        exit 1
    }

    $inventory | where {|host| $host.name in $requested }
}

def ssh-command-with [host: record, command: string, run_ssh: closure] {
    let destination = $"($host.healthUser)@($host.targetHost)"
    let control_path = $"/tmp/nix-config-health-($nu.pid)-%C"
    let common_arguments = [
        -p
        ($host.targetPort | into string)
        -o
        BatchMode=yes
        -o
        ConnectTimeout=12
        -o
        ConnectionAttempts=3
        -o
        ServerAliveInterval=5
        -o
        ServerAliveCountMax=2
    ]
    let first_arguments = (
        $common_arguments
        | append [-o ControlMaster=auto -o ControlPersist=60 -o $"ControlPath=($control_path)"]
        | append [$destination $command]
    )
    let first = (do $run_ssh $first_arguments)

    if $first.exit_code == 0 {
        return $first
    }

    let ssh_error = ($first.stderr | str downcase)
    let mux_failed = [
        "mux_client_request_session"
        "control socket connect"
        "control master"
    ] | any {|message| $ssh_error | str contains $message }

    if not $mux_failed {
        return $first
    }

    print -e $"[WARN] ($host.name): SSH multiplexing failed; retrying with a fresh connection"
    let retry_arguments = (
        $common_arguments
        | append [-o ControlMaster=no -o ControlPath=none]
        | append [$destination $command]
    )
    do $run_ssh $retry_arguments
}

def ssh-command [host: record, command: string] {
    ssh-command-with $host $command {|arguments|
        ^ssh ...$arguments | complete
    }
}

def root-health-command [host: record, helper: string, action: string, since_minutes: int] {
    ssh-command $host $"sudo -n ($helper) ($action) ($since_minutes)"
}

def since-to-minutes [since: string] {
    if $since !~ '^-[0-9]+ (minute|minutes|hour|hours)$' {
        print -e $"[FAIL] unsupported --since value: ($since)"
        print -e "[INFO] use values such as '-15 minutes' or '-1 hour'"
        exit 1
    }

    let parts = ($since | split row " ")
    let value = ($parts.0 | str replace "-" "" | into int)
    if ($parts.1 | str starts-with "hour") {
        $value * 60
    } else {
        $value
    }
}

def ping-loss [output: string] {
    let rows = (
        $output
        | lines
        | parse --regex '(?P<loss>[0-9.]+)% packet loss'
    )

    if ($rows | is-empty) {
        null
    } else {
        ($rows | last | get loss | into float)
    }
}

def check-ping [host: record, address: string, ipv6: bool, label: string] {
    let family = if $ipv6 { "-6" } else { "-4" }
    let first = (ssh-command $host $"ping ($family) -c 5 -W 3 ($address)")
    let first_loss = (ping-loss $first.stdout)
    if ($first.exit_code == 0) and ($first_loss != null) and ($first_loss == 0.0) {
        print $"[PASS] ($host.name): ($label) reachable without loss"
        return 0
    }

    print $"[INFO] ($host.name): retrying ($label) after a lossy/failed probe"
    let retry = (ssh-command $host $"ping ($family) -c 10 -i 0.2 -W 3 ($address)")
    let retry_loss = (ping-loss $retry.stdout)
    if ($retry.exit_code == 0) and ($retry_loss != null) and ($retry_loss <= 10.0) {
        if $retry_loss == 0.0 {
            print $"[PASS] ($host.name): ($label) retry passed without loss"
        } else {
            print $"[WARN] ($host.name): ($label) reachable with ($retry_loss)% loss"
        }
        0
    } else {
        print -e $"[FAIL] ($host.name): ($label) is unreachable or lossy"
        let details = (($retry.stdout + $retry.stderr) | str trim)
        if $details != "" {
            print -e $details
        }
        1
    }
}

def check-http-probes [host: record, root_helper: string, since_minutes: int] {
    let probes = ($host.httpProbes | transpose unit url)
    mut failures = 0

    for probe in $probes {
        let result = (ssh-command $host $"curl --fail --silent --show-error --max-time 8 ($probe.url)")
        if $result.exit_code == 0 {
            print $"[PASS] ($host.name): ($probe.unit) HTTP probe"
        } else {
            print -e $"[FAIL] ($host.name): ($probe.unit) HTTP probe failed: ($probe.url)"
            print -e (($result.stdout + $result.stderr) | str trim)
            $failures = $failures + 1
        }
    }

    if "postgresql" in $host.requiredUnits {
        let result = (root-health-command $host $root_helper "postgresql" $since_minutes)
        if ($result.exit_code == 0) and (($result.stdout | str trim) == "1") {
            print $"[PASS] ($host.name): PostgreSQL query probe"
        } else {
            print -e $"[FAIL] ($host.name): PostgreSQL query probe failed"
            print -e (($result.stdout + $result.stderr) | str trim)
            $failures = $failures + 1
        }
    }

    $failures
}

def check-deployment-host [host: record, reference: record, since_minutes: int] {
    mut failures = 0
    print $"\n[INFO] checking ($host.name) via ($host.healthUser)@($host.targetHost)"

    let hostname = (ssh-command $host "hostname")
    if ($hostname.exit_code == 0) and (($hostname.stdout | str trim) == $host.name) {
        print $"[PASS] ($host.name): SSH and hostname"
    } else {
        print -e $"[FAIL] ($host.name): SSH failed or hostname mismatch"
        print -e (($hostname.stdout + $hostname.stderr) | str trim)
        return 1
    }

    let helper_result = (ssh-command $host "readlink -f /run/current-system/sw/bin/deployment-health-root")
    let root_helper = ($helper_result.stdout | str trim)
    if ($helper_result.exit_code != 0) or (not ($root_helper | str starts-with "/nix/store/")) or (not ($root_helper | str ends-with "/bin/deployment-health-root")) {
        print -e $"[FAIL] ($host.name): privileged health-check helper is missing or invalid"
        print -e (($helper_result.stdout + $helper_result.stderr) | str trim)
        return 1
    }

    let system_state = (ssh-command $host "systemctl is-system-running")
    if ($system_state.exit_code == 0) and (($system_state.stdout | str trim) == "running") {
        print $"[PASS] ($host.name): systemd system state is running"
    } else {
        print -e $"[FAIL] ($host.name): systemd state is (($system_state.stdout | str trim))"
        $failures = $failures + 1
    }

    let current_kernel = (ssh-command $host "readlink -f /run/current-system/kernel")
    let booted_kernel = (ssh-command $host "readlink -f /run/booted-system/kernel")
    if ($current_kernel.exit_code == 0) and ($booted_kernel.exit_code == 0) {
        let current = ($current_kernel.stdout | str trim)
        let booted = ($booted_kernel.stdout | str trim)
        if $current == $booted {
            print $"[PASS] ($host.name): running the current kernel"
        } else {
            print $"[WARN] ($host.name): reboot required to run the current kernel"
            print $"       current: ($current)"
            print $"       booted:  ($booted)"
        }
    }

    let failed_units = (ssh-command $host "systemctl --failed --no-legend --no-pager")
    if ($failed_units.exit_code == 0) and (($failed_units.stdout | str trim) == "") {
        print $"[PASS] ($host.name): no failed systemd units"
    } else {
        print -e $"[FAIL] ($host.name): failed systemd units detected"
        print -e (($failed_units.stdout + $failed_units.stderr) | str trim)
        $failures = $failures + 1
    }

    if not ($host.requiredUnits | is-empty) {
        let units = ($host.requiredUnits | each {|unit| $"($unit).service" } | str join " ")
        let active_units = (ssh-command $host $"systemctl is-active ($units)")
        if $active_units.exit_code == 0 {
            print $"[PASS] ($host.name): (($host.requiredUnits | length)) required systemd units active"
        } else {
            print -e $"[FAIL] ($host.name): one or more required systemd units inactive"
            print -e (($active_units.stdout + $active_units.stderr) | str trim)
            $failures = $failures + 1
        }
    }

    if "auditd" in $host.requiredUnits {
        let audit = (root-health-command $host $root_helper "audit-status" $since_minutes)
        let fields = if $audit.exit_code == 0 {
            $audit.stdout | lines | parse "{name} {value}"
        } else {
            []
        }
        let lost_rows = ($fields | where name == "lost")
        let backlog_rows = ($fields | where name == "backlog")

        if (not ($lost_rows | is-empty)) and (not ($backlog_rows | is-empty)) {
            let lost = ($lost_rows.0.value | into int)
            let backlog = ($backlog_rows.0.value | into int)
            if ($lost == 0) and ($backlog == 0) {
                print $"[PASS] ($host.name): audit lost and backlog counters are zero"
            } else {
                print -e $"[FAIL] ($host.name): audit lost=($lost), backlog=($backlog)"
                $failures = $failures + 1
            }
        } else {
            print -e $"[FAIL] ($host.name): unable to read audit status"
            print -e (($audit.stdout + $audit.stderr) | str trim)
            $failures = $failures + 1
        }
    }

    if $host.features.zerotier {
        let zerotier = (root-health-command $host $root_helper "zerotier-status" $since_minutes)
        if ($zerotier.exit_code == 0) and ($zerotier.stdout | str contains "ONLINE") {
            print $"[PASS] ($host.name): ZeroTier ONLINE"
        } else {
            print -e $"[FAIL] ($host.name): ZeroTier is not ONLINE"
            print -e (($zerotier.stdout + $zerotier.stderr) | str trim)
            $failures = $failures + 1
        }
    }

    if "bird" in $host.requiredUnits {
        let bird = (root-health-command $host $root_helper "bird-protocols" $since_minutes)
        if $bird.exit_code != 0 {
            print -e $"[FAIL] ($host.name): BIRD control socket failed"
            print -e (($bird.stdout + $bird.stderr) | str trim)
            $failures = $failures + 1
        } else {
            let internal_bgp = ($bird.stdout | lines | where {|line| $line | str contains "ibgp_loki_net_" })
            let bad_bgp = ($internal_bgp | where {|line| not ($line | str contains "Established") })
            let ospf = ($bird.stdout | lines | where {|line| $line =~ '^slk_ospf_' })
            let bad_ospf = ($ospf | where {|line| not ($line | str contains "Running") })

            if ($bad_bgp | is-empty) and ($bad_ospf | is-empty) {
                print $"[PASS] ($host.name): internal BGP and OSPF protocols healthy"
            } else {
                print -e $"[FAIL] ($host.name): unhealthy internal routing protocols"
                $bad_bgp | append $bad_ospf | each {|line| print -e $line }
                $failures = $failures + 1
            }
        }
    }

    if $host.networks.dn42.anycastDns {
        let dns = (ssh-command $host "dig +time=5 +tries=1 +short @127.0.0.1 slk.dn42 SOA")
        if ($dns.exit_code == 0) and (($dns.stdout | str trim) != "") {
            print $"[PASS] ($host.name): local DN42 DNS SOA query"
        } else {
            print -e $"[FAIL] ($host.name): local DN42 DNS query failed"
            print -e (($dns.stdout + $dns.stderr) | str trim)
            $failures = $failures + 1
        }
    }

    if ($host.kind == "vps") and ($host.name != $reference.name) {
        $failures = $failures + (check-ping $host $reference.networks.slk-net.ipv4 false $"SLK IPv4 -> ($reference.name)")
        $failures = $failures + (check-ping $host $reference.networks.slk-net.ipv6 true $"SLK IPv6 -> ($reference.name)")
        if $reference.networks.loki-net.enable {
            $failures = $failures + (check-ping $host $reference.networks.loki-net.ipv6 true $"Loki-Net IPv6 -> ($reference.name)")
        }
    }

    $failures = $failures + (check-http-probes $host $root_helper $since_minutes)

    let journal = (root-health-command $host $root_helper "journal" $since_minutes)
    if $journal.exit_code != 0 {
        print -e $"[FAIL] ($host.name): unable to read high-priority journal"
        print -e (($journal.stdout + $journal.stderr) | str trim)
        $failures = $failures + 1
    } else {
        let unexpected = (
            $journal.stdout
            | lines
            | where {|line|
                let trimmed = ($line | str trim)
                let duplicate_dbus = ($line | str contains "Ignoring duplicate name")
                let ssh_preauth_reset = (($line | str contains "kex_exchange_identification") and ($line | str contains "[preauth]"))
                ($trimmed != "") and ($trimmed != "-- No entries --") and not $duplicate_dbus and not $ssh_preauth_reset
            }
        )
        if ($unexpected | is-empty) {
            print $"[PASS] ($host.name): no unexpected priority 0..3 logs in the last ($since_minutes) minute\(s\)"
        } else {
            print -e $"[FAIL] ($host.name): unexpected priority 0..3 logs in the last ($since_minutes) minute\(s\)"
            $unexpected | first 30 | each {|line| print -e $line }
            $failures = $failures + 1
        }
    }

    if $failures == 0 {
        print $"[PASS] ($host.name): health checks passed"
    } else {
        print -e $"[FAIL] ($host.name): ($failures) health check\(s\) failed"
    }
    $failures
}

def run-deployment-health [inventory: list<any>, selected: list<any>, since: string] {
    let references = ($inventory | where name == "Test-NixOS")
    if ($references | is-empty) {
        print -e "[FAIL] Test-NixOS is missing from the deployment inventory"
        exit 1
    }
    let reference = ($references | first)
    let since_minutes = (since-to-minutes $since)
    mut failures = 0

    for host in $selected {
        $failures = $failures + (check-deployment-host $host $reference $since_minutes)
    }

    if $failures == 0 {
        print $"\n[PASS] deployment health checks passed for (($selected | length)) host\(s\)"
    } else {
        print -e $"\n[FAIL] ($failures) deployment health check\(s\) failed"
    }
    $failures
}

def apply-colmena-hosts [hosts: list<any>, parallel: int] {
    if ($hosts | is-empty) {
        return 0
    }

    let selector = ($hosts | get name | str join ",")
    print $"[INFO] deploying with Colmena: ($selector)"
    ^colmena apply --on $selector --parallel ($parallel | into string) --verbose --show-trace
    let exit_code = $env.LAST_EXIT_CODE
    if $exit_code != 0 {
        print -e $"[FAIL] Colmena deployment failed: ($selector)"
    }
    $exit_code
}

def deployment-rollout-with [
    inventory: list<any>
    parallel: int
    since: string
    apply_hosts: closure
    run_health: closure
] {
    let canary = (select-deployment-hosts $inventory ["Test-NixOS"])
    let remaining = ($inventory | where name != "Test-NixOS")

    let canary_exit_code = (do $apply_hosts $canary $parallel)
    if $canary_exit_code != 0 {
        return $canary_exit_code
    }

    let canary_failures = (do $run_health $inventory $canary $since)
    if $canary_failures != 0 {
        print -e "[FAIL] Test-NixOS canary failed; remaining hosts were not deployed"
        return 1
    }

    let remaining_exit_code = (do $apply_hosts $remaining $parallel)
    if $remaining_exit_code != 0 {
        return $remaining_exit_code
    }

    let failures = (do $run_health $inventory $inventory $since)
    if $failures != 0 {
        return 1
    }

    print "[PASS] canary-first deployment rollout completed"
    0
}

def ensure-deployment-worktree [] {
    let git_status = (git status --porcelain | complete)
    if ($git_status.exit_code != 0) or (($git_status.stdout | str trim) != "") {
        print -e "[FAIL] deployment requires a clean Git worktree"
        if (($git_status.stdout | str trim) != "") {
            print -e ($git_status.stdout | str trim)
        }
        print -e "[INFO] commit or stash changes before deploying"
        exit 1
    }
}

def run-deployment-preflight [] {
    print "[INFO] running flake checks before deployment"
    ^nix flake check --all-systems --no-build --show-trace
    if $env.LAST_EXIT_CODE != 0 {
        print -e "[FAIL] flake checks failed; deployment stopped"
        exit $env.LAST_EXIT_CODE
    }
}

export def deployment-health [
    --since: string = "-15 minutes"
    ...hosts: string
] {
    let inventory = (deployment-inventory)
    let selected = (select-deployment-hosts $inventory $hosts)
    let failures = (run-deployment-health $inventory $selected $since)
    if $failures != 0 {
        exit 1
    }
}

export def deployment-test [
    --parallel: int = 2
    --skip-check
    --since: string = "-15 minutes"
] {
    ensure-deployment-worktree
    if not $skip_check {
        run-deployment-preflight
    }

    let inventory = (deployment-inventory)
    let selected = (select-deployment-hosts $inventory ["Test-NixOS"])
    let apply_exit_code = (apply-colmena-hosts $selected $parallel)
    if $apply_exit_code != 0 {
        exit $apply_exit_code
    }
    let failures = (run-deployment-health $inventory $selected $since)
    if $failures != 0 {
        print -e "[FAIL] Test-NixOS canary failed; rollout stopped"
        exit 1
    }
}

export def deployment-rollout [
    --parallel: int = 2
    --skip-check
    --since: string = "-15 minutes"
] {
    ensure-deployment-worktree
    if not $skip_check {
        run-deployment-preflight
    }

    let inventory = (deployment-inventory)
    let exit_code = (deployment-rollout-with $inventory $parallel $since {|hosts, limit|
        apply-colmena-hosts $hosts $limit
    } {|all_hosts, selected, health_since|
        run-deployment-health $all_hosts $selected $health_since
    })
    if $exit_code != 0 {
        exit $exit_code
    }
}

# ====================== Misc =============================

export def make-editable [
    path: string
] {
    let tmpdir = (mktemp -d)
    rsync -avz --copy-links $"($path)/" $tmpdir
    rsync -avz --copy-links --chmod=D2755,F744 $"($tmpdir)/" $path
}

# ================= macOS related =========================

export def darwin-build [
    name: string
    mode: string
] {
    let target = $".#darwinConfigurations.($name).system"
    if "debug" == $mode {
        nom build $target --extra-experimental-features "nix-command flakes"  --show-trace --verbose
    } else {
        nix build $target --extra-experimental-features "nix-command flakes"
    }
}

export def darwin-switch [
    name: string
    mode: string
] {
    if "debug" == $mode {
        sudo ./result/sw/bin/darwin-rebuild switch --flake $".#($name)" --show-trace --verbose
    } else {
        sudo ./result/sw/bin/darwin-rebuild switch --flake $".#($name)"
    }
}

export def darwin-rollback [] {
    sudo ./result/sw/bin/darwin-rebuild --rollback
}

# Build and upload a VM image
export def upload-vm [
    name: string
    mode: string
] {
    let target = $".#($name)"
    if "debug" == $mode {
        nom build $target --show-trace --verbose
    } else {
        nix build $target
    }

    let remote = $"root@Server-NixOS:/data/apps/caddy/fileserver/vms/($name).qcow2"
    rsync -avz --progress --copy-links --checksum result/nixos.qcow2 $remote
}

# Build and upload a ISO
export def upload-iso [
    name: string
    mode: string
] {
    let target = $".#($name)"
    if "debug" == $mode {
        nom build $target --show-trace --verbose
    } else {
        nix build $target
    }

    let remote = $"root@Server-NixOS:/data/apps/caddy/fileserver/vms/($name).iso"
    rsync -avz --progress --copy-links --checksum result/nixos.iso $remote
}
