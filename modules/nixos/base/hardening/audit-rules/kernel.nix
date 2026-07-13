{ helpers, ... }:

helpers.syscallRules [
  "init_module"
  "finit_module"
  "delete_module"
] "kernel_modules"
++ helpers.syscallRules [
  "settimeofday"
  "clock_settime"
  "adjtimex"
] "time_change"
