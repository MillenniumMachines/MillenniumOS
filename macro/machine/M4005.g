; M4005.g: Check MillenniumOS Post Version

if { !exists(param.V) }
    abort { "Must pass post-processor version (V...)"}

if { param.V != global.mosVer }
    abort { "MillenniumOS: Post-processor version " ^ param.V ^ " does not match installed version " ^ global.mosVer ^ "!" }