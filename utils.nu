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
