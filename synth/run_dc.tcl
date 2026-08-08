set root_dir [file normalize [file join [file dirname [info script]] ..]]
set report_dir [file join $root_dir reports generated dc]
file mkdir $report_dir

if {![info exists ::env(DC_TARGET_LIBRARY)] || $::env(DC_TARGET_LIBRARY) eq ""} {
    echo "ERROR: set DC_TARGET_LIBRARY to an absolute standard-cell .db path"
    exit 2
}

set target_library [list $::env(DC_TARGET_LIBRARY)]
set link_library [concat * $target_library]
if {[info exists ::env(DC_ADDITIONAL_LINK_LIBRARIES)] &&
    $::env(DC_ADDITIONAL_LINK_LIBRARIES) ne ""} {
    set link_library [concat $link_library $::env(DC_ADDITIONAL_LINK_LIBRARIES)]
}

set_app_var hdlin_enable_presto_for_vhdl false
set_app_var verilogout_no_tri true

set rtl_files [list \
    [file join $root_dir rtl complex_mult.sv] \
    [file join $root_dir rtl complex_mac.sv] \
    [file join $root_dir rtl fixed_round_sat.sv] \
    [file join $root_dir rtl matrix_storage.sv] \
    [file join $root_dir rtl symbol_buffer.sv] \
    [file join $root_dir rtl precoder_core.sv] \
    [file join $root_dir rtl axi_stream_reorder_buffer.sv]]

analyze -format sverilog $rtl_files
elaborate precoder_core
current_design precoder_core
link
check_design > [file join $report_dir check_design.rpt]

source [file join $root_dir synth constraints.sdc]
compile_ultra

report_qor > [file join $report_dir qor.rpt]
report_area -hierarchy > [file join $report_dir area.rpt]
report_timing -delay_type max -max_paths 20 -nworst 2 > [file join $report_dir timing_max.rpt]
report_timing -delay_type min -max_paths 20 -nworst 2 > [file join $report_dir timing_min.rpt]
report_constraint -all_violators > [file join $report_dir constraints.rpt]
report_reference -hierarchy > [file join $report_dir references.rpt]
report_resources -hierarchy > [file join $report_dir resources.rpt]

write -format verilog -hierarchy -output [file join $report_dir precoder_core_mapped.v]
write_sdc [file join $report_dir precoder_core_mapped.sdc]
write_sdf -version 2.1 [file join $report_dir precoder_core_mapped.sdf]
write -format ddc -hierarchy -output [file join $report_dir precoder_core.ddc]
exit
