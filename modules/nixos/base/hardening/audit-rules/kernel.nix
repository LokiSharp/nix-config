[
  "-a always,exit -F arch=b64 -S init_module -S finit_module -S delete_module -k kernel_modules"
  "-a always,exit -F arch=b64 -S settimeofday -S clock_settime -S adjtimex -k time_change"
]
