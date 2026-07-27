source ../utils.nu

def assert [condition: bool, message: string] {
    if not $condition {
        error make {msg: $message}
    }
}

def has-argument [arguments: list<string>, expected: string] {
    $arguments | any {|argument| $argument == $expected }
}

def is-initial-attempt [arguments: list<string>] {
    has-argument $arguments "ControlMaster=auto"
}

def is-fallback-attempt [arguments: list<string>] {
    (has-argument $arguments "ControlMaster=no") and (has-argument $arguments "ControlPath=none")
}

let host = {
    name: Test-NixOS
    healthUser: root
    targetHost: 192.0.2.10
    targetPort: 2222
}

let success = (ssh-command-with $host hostname {|arguments|
    assert (is-initial-attempt $arguments) "successful SSH command unexpectedly retried"
    {
        stdout: ($arguments | to json --raw)
        stderr: ""
        exit_code: 0
    }
})
let initial_arguments = ($success.stdout | from json)
assert ($success.exit_code == 0) "successful SSH result was not returned"
assert (has-argument $initial_arguments "-p") "SSH port flag is missing"
assert (has-argument $initial_arguments "2222") "configured SSH port is missing"
assert (has-argument $initial_arguments "root@192.0.2.10") "SSH destination is missing"
assert (has-argument $initial_arguments "hostname") "remote command is missing"
assert (
    $initial_arguments | any {|argument|
        (
            ($argument | str starts-with "ControlPath=/tmp/nix-config-health-")
            and ($argument | str ends-with "-%C")
        )
    }
) "initial SSH attempt does not use a process-scoped control path"

let ordinary_failure = (ssh-command-with $host hostname {|arguments|
    if not (is-initial-attempt $arguments) {
        error make {msg: "ordinary SSH failure unexpectedly retried"}
    }
    {
        stdout: ""
        stderr: "ssh: connect to host 192.0.2.10 port 2222: Connection refused"
        exit_code: 255
    }
})
assert ($ordinary_failure.exit_code == 255) "ordinary SSH failure exit code was not preserved"
assert (
    $ordinary_failure.stderr | str contains "Connection refused"
) "ordinary SSH failure stderr was not preserved"

let mux_errors = [
    "mux_client_request_session: session request failed"
    "Control socket connect(/tmp/example): Connection refused"
    "Control master terminated unexpectedly"
]

for mux_error in $mux_errors {
    let fallback = (ssh-command-with $host hostname {|arguments|
        if (is-initial-attempt $arguments) {
            {
                stdout: ""
                stderr: $mux_error
                exit_code: 255
            }
        } else if (is-fallback-attempt $arguments) {
            {
                stdout: ($arguments | to json --raw)
                stderr: ""
                exit_code: 0
            }
        } else {
            error make {msg: "SSH fallback used unexpected arguments"}
        }
    })
    let fallback_arguments = ($fallback.stdout | from json)
    assert ($fallback.exit_code == 0) $"mux error did not recover: ($mux_error)"
    assert (
        not (has-argument $fallback_arguments "ControlMaster=auto")
    ) "SSH fallback retained multiplexing"
    assert (is-fallback-attempt $fallback_arguments) "SSH fallback did not disable multiplexing"
}

let failed_fallback = (ssh-command-with $host hostname {|arguments|
    if (is-initial-attempt $arguments) {
        {
            stdout: ""
            stderr: "mux_client_request_session: session request failed"
            exit_code: 255
        }
    } else {
        {
            stdout: ""
            stderr: "fallback connection failed"
            exit_code: 42
        }
    }
})
assert ($failed_fallback.exit_code == 42) "SSH fallback exit code was not returned"
assert ($failed_fallback.stderr == "fallback connection failed") "SSH fallback stderr was not returned"
