_:
let
  hostName = "MacbookAir";
in
{
  networking.hostName = hostName;
  networking.computerName = hostName;
  system.defaults.smb.NetBIOSName = hostName;
}
