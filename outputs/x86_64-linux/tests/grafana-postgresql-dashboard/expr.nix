{ lib, mylib, ... }:
let
  dashboardPath =
    "hosts/server-nixos/services/grafana/dashboards/databases/postgresql-overview.json";
  dashboard = builtins.fromJSON (builtins.readFile (mylib.relativeToRoot dashboardPath));
  panelTitles = map (panel: panel.title) dashboard.panels;
  panelTypes = map (panel: panel.type) dashboard.panels;
  expressions = lib.concatMap
    (panel: map (target: target.expr or "") (panel.targets or [ ]))
    dashboard.panels;
  variableNames = map (variable: variable.name) dashboard.templating.list;
  requiredPanels = [
    "PostgreSQL availability"
    "Connection utilization"
    "Selected database size"
    "Longest transaction"
    "Exporter scrape state"
    "Collector failures"
    "WAL size"
    "Replication lag"
    "Connections by database"
    "Sessions by state"
    "Transaction rate"
    "Cache hit ratio"
    "Tuple operation rate"
    "Locks by mode"
    "Deadlocks and conflicts"
    "Temporary file activity"
    "Background writer buffers"
    "Checkpoint time accumulation"
    "Exporter collector duration"
  ];
  requiredQueryFragments = [
    "pg_up"
    "pg_stat_database_numbackends"
    "pg_database_size_bytes"
    "pg_stat_activity_max_tx_duration"
    "pg_stat_database_xact_commit"
    "pg_stat_database_blks_hit"
    "pg_locks_count"
    "pg_stat_database_deadlocks"
    "pg_stat_database_temp_bytes"
    "pg_stat_bgwriter_buffers_alloc_total"
    "pg_wal_size_bytes"
    "pg_scrape_collector_duration_seconds"
    "$__rate_interval"
  ];
in
{
  dashboardIdentityConfigured =
    dashboard.uid == "postgresql-overview"
    && dashboard.title == "PostgreSQL Overview"
    && dashboard.schemaVersion == 41;
  expectedPanelsConfigured =
    lib.length dashboard.panels == lib.length requiredPanels
    && lib.all (title: builtins.elem title panelTitles) requiredPanels;
  modernPanelTypesOnly = lib.all
    (panelType: !(builtins.elem panelType [ "graph" "singlestat" ]))
    panelTypes;
  environmentVariablesConfigured = lib.all
    (name: builtins.elem name variableNames)
    [ "datasource" "host" "instance" "datname" ];
  kubernetesVariablesAbsent = lib.all
    (name: !(builtins.elem name variableNames))
    [ "namespace" "release" ];
  kubernetesSelectorsAbsent = lib.all
    (expression:
      !(lib.hasInfix "kubernetes_namespace" expression)
      && !(lib.hasInfix "release=" expression))
    expressions;
  requiredQueriesConfigured = lib.all
    (fragment: lib.any (expression: lib.hasInfix fragment expression) expressions)
    requiredQueryFragments;
  currentBgwriterCountersUsed = lib.all
    (expression:
      !(lib.hasInfix "pg_stat_bgwriter" expression)
      || lib.hasInfix "_total" expression)
    expressions;
  legacyDashboardAbsent = !(builtins.pathExists (
    mylib.relativeToRoot
      "hosts/server-nixos/services/grafana/dashboards/databases/postgresql-database.json"
  ));
}
