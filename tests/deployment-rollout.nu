source ../utils.nu

def assert [condition: bool, message: string] {
    if not $condition {
        error make {msg: $message}
    }
}

def host-names [hosts: list<any>] {
    $hosts | get name
}

def record-event [log: path, kind: string, hosts: list<any>, detail: any] {
    let event = {
        kind: $kind
        hosts: (host-names $hosts)
        detail: $detail
    }
    $"($event | to json --raw)\n" | save --append $log
}

def read-events [log: path] {
    open $log | lines | each {|line| $line | from json }
}

def new-log [] {
    let log = (mktemp)
    "" | save --force $log
    $log
}

let inventory = [
    {name: Test-NixOS}
    {name: Server-NixOS}
    {name: VM-NixOS}
]
let parallel = 3
let since = "-20 minutes"

let success_log = (new-log)
let success = (deployment-rollout-with $inventory $parallel $since {|hosts, limit|
    record-event $success_log apply $hosts $limit
    0
} {|_, selected, health_since|
    record-event $success_log health $selected $health_since
    0
})
assert ($success == 0) "successful rollout returned a failure"
assert ((read-events $success_log) == [
    {kind: apply, hosts: [Test-NixOS], detail: 3}
    {kind: health, hosts: [Test-NixOS], detail: "-20 minutes"}
    {kind: apply, hosts: [Server-NixOS, VM-NixOS], detail: 3}
    {kind: health, hosts: [Test-NixOS, Server-NixOS, VM-NixOS], detail: "-20 minutes"}
]) "successful rollout did not preserve canary-first ordering"

let canary_deploy_log = (new-log)
let canary_deploy_failure = (deployment-rollout-with $inventory $parallel $since {|hosts, limit|
    record-event $canary_deploy_log apply $hosts $limit
    23
} {|_, selected, health_since|
    record-event $canary_deploy_log health $selected $health_since
    0
})
assert ($canary_deploy_failure == 23) "canary deployment exit code was not preserved"
assert ((read-events $canary_deploy_log) == [
    {kind: apply, hosts: [Test-NixOS], detail: 3}
]) "canary deployment failure did not stop the rollout"

let canary_health_log = (new-log)
let canary_health_failure = (deployment-rollout-with $inventory $parallel $since {|hosts, limit|
    record-event $canary_health_log apply $hosts $limit
    0
} {|_, selected, health_since|
    record-event $canary_health_log health $selected $health_since
    2
})
assert ($canary_health_failure == 1) "canary health failure did not fail the rollout"
assert ((read-events $canary_health_log) == [
    {kind: apply, hosts: [Test-NixOS], detail: 3}
    {kind: health, hosts: [Test-NixOS], detail: "-20 minutes"}
]) "canary health failure did not stop before remaining hosts"

let remaining_deploy_log = (new-log)
let remaining_deploy_failure = (deployment-rollout-with $inventory $parallel $since {|hosts, limit|
    record-event $remaining_deploy_log apply $hosts $limit
    if (host-names $hosts) == [Test-NixOS] { 0 } else { 42 }
} {|_, selected, health_since|
    record-event $remaining_deploy_log health $selected $health_since
    0
})
assert ($remaining_deploy_failure == 42) "remaining deployment exit code was not preserved"
assert ((read-events $remaining_deploy_log) == [
    {kind: apply, hosts: [Test-NixOS], detail: 3}
    {kind: health, hosts: [Test-NixOS], detail: "-20 minutes"}
    {kind: apply, hosts: [Server-NixOS, VM-NixOS], detail: 3}
]) "remaining deployment failure did not stop before final health checks"

let final_health_log = (new-log)
let final_health_failure = (deployment-rollout-with $inventory $parallel $since {|hosts, limit|
    record-event $final_health_log apply $hosts $limit
    0
} {|_, selected, health_since|
    record-event $final_health_log health $selected $health_since
    if (host-names $selected) == [Test-NixOS] { 0 } else { 3 }
})
assert ($final_health_failure == 1) "final health failure did not fail the rollout"
assert ((read-events $final_health_log) == [
    {kind: apply, hosts: [Test-NixOS], detail: 3}
    {kind: health, hosts: [Test-NixOS], detail: "-20 minutes"}
    {kind: apply, hosts: [Server-NixOS, VM-NixOS], detail: 3}
    {kind: health, hosts: [Test-NixOS, Server-NixOS, VM-NixOS], detail: "-20 minutes"}
]) "final health failure changed the rollout ordering"

assert (
    (apply-colmena-hosts [] $parallel) == 0
) "an empty host list did not return without invoking Colmena"
