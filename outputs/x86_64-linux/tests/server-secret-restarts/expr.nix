{ outputs, ... }:
let
  templates = outputs.nixosConfigurations.Server-NixOS.config.sops.templates;
in
{
  grafana = builtins.elem "grafana.service" templates."grafana-env".restartUnits;
  minio = builtins.elem "minio.service" templates."minio-root-credentials".restartUnits;
  sftpgo = builtins.elem "sftpgo.service" templates."sftpgo-env".restartUnits;
}
