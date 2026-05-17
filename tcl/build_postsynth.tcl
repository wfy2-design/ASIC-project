set script_dir [file dirname [file normalize [info script]]]
read_verilog [file join $script_dir sv debouncer.sv]
read_verilog [file join $script_dir sv reaction_core.sv]
read_verilog [file join $script_dir sv display_7seg.sv]
read_verilog [file join $script_dir sv beep_led_fx.sv]
read_verilog [file join $script_dir sv vga_renderer.sv]
read_verilog [file join $script_dir sv reaction_tester_top.sv]
synth_design -top reaction_tester_top -part xc7a35tcpg236-1 -generic CLK_HZ=1000 -generic KEY_ACTIVE_LOW=0
write_verilog -force -mode timesim [file join $script_dir reaction_tester_top_timesim.v]
write_sdf -force [file join $script_dir reaction_tester_top_timesim.sdf]

