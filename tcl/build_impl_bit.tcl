set script_dir [file dirname [file normalize [info script]]]
read_verilog [file join $script_dir sv debouncer.sv]
read_verilog [file join $script_dir sv reaction_core.sv]
read_verilog [file join $script_dir sv display_7seg.sv]
read_verilog [file join $script_dir sv beep_led_fx.sv]
read_verilog [file join $script_dir sv vga_renderer.sv]
read_verilog [file join $script_dir sv reaction_tester_top.sv]
read_xdc [file join $script_dir xdc project.xdc]
synth_design -top reaction_tester_top -part xc7a35tcpg236-1
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -max_paths 10 -report_unconstrained -warn_on_violation -file [file join $script_dir impl_timing_summary.rpt]
report_utilization -file [file join $script_dir impl_utilization.rpt]
write_checkpoint -force [file join $script_dir reaction_tester_top_impl_routed.dcp]
write_bitstream -force [file join $script_dir reaction_tester_top.bit]

