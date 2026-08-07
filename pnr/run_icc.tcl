set root_dir [file normalize [file join [file dirname [info script]] ..]]
set build_dir [file join $root_dir build icc]
set report_dir [file join $root_dir reports generated icc]
file mkdir $build_dir
file mkdir $report_dir

set lib_root /cad/eda_lib/smic55nm_2020/SCC55NLL_VHS_STDCELL/SCC55NLL_VHS_RVT_lib_V2.1/SCC55NLL_VHS_RVT_V2.1/SCC55NLL_VHS_RVT_V2p1
set timing_root /cad/eda_lib/smic55nm_2020/SCC55NLL_VHS_STDCELL/SCC55NLL_VHS_RVT_lib_V2.1/SCC55NLL_VHS_RVT_V2p1/liberty/1.2v
set tech_file [file join $lib_root astro tf_tm scc55nll_vhs_10m_8ic_2tmc_alpa1.tf]
set reference_lib [file join $lib_root astro scc55nll_vhs_rvt]
set tlu_dir [file join $lib_root astro tluplus 1P10M_8Ic_2TMc_ALPA1]
set max_tlu [file join $tlu_dir StarRC_55LLULP_1P10M_8Ic_2TMc_ALPA1_RCMAX.tluplus]
set min_tlu [file join $tlu_dir StarRC_55LLULP_1P10M_8Ic_2TMc_ALPA1_RCMIN.tluplus]
set tech_map [file join $tlu_dir StarRC_55LLULP_1P10M_8Ic_2TMc_ALPA1_cell.map]
set target_library [file join $timing_root scc55nll_vhs_rvt_tt_v1p2_25c_basic.db]
set netlist [file join $root_dir reports generated dc precoder_core_mapped.v]
set constraints [file join $root_dir reports generated dc precoder_core_mapped.sdc]
set design_lib [file join $build_dir precoder_core_mw]

set_app_var target_library [list $target_library]
set_app_var link_library [concat * $target_library]
if {[file exists $design_lib]} { file delete -force $design_lib }
create_mw_lib -technology $tech_file -mw_reference_library [list $reference_lib] $design_lib
open_mw_lib $design_lib
set_tlu_plus_files -max_tluplus $max_tlu -min_tluplus $min_tlu -tech2itf_map $tech_map
check_tlu_plus_files > [file join $report_dir tlu_check.rpt]
import_designs -format verilog -top precoder_core -cel precoder_core $netlist
read_sdc $constraints
set_fix_multiple_port_nets -all -buffer_constants
derive_pg_connection -power_net VDD -power_pin VDD -ground_net VSS -ground_pin VSS
derive_pg_connection -power_net VDD -power_pin VNW -ground_net VSS -ground_pin VPW
create_floorplan -control_type aspect_ratio -core_aspect_ratio 1.0 -core_utilization 0.65 -left_io2core 10 -bottom_io2core 10 -right_io2core 10 -top_io2core 10
check_design > [file join $report_dir check_design_import.rpt]
check_physical_design -stage pre_place > [file join $report_dir check_physical_pre_place.rpt]
report_utilization > [file join $report_dir utilization_floorplan.rpt]
report_timing -max_paths 10 > [file join $report_dir timing_floorplan.rpt]
save_mw_cel -as floorplan
set_host_options -max_cores 4
place_opt
check_legality > [file join $report_dir check_legality_placement.rpt]
check_physical_design -stage pre_clock_opt > [file join $report_dir check_physical_placement.rpt]
report_qor > [file join $report_dir qor_placement.rpt]
report_timing -max_paths 20 > [file join $report_dir timing_placement.rpt]
report_congestion -grc_based > [file join $report_dir congestion_placement.rpt]
save_mw_cel -as placement
set_clock_tree_options -target_skew 0.10 -max_transition 0.20
set_clock_tree_references -references [get_lib_cells */BUFVHSV*]
clock_opt -only_cts
check_legality > [file join $report_dir check_legality_cts.rpt]
check_physical_design -stage pre_route_opt > [file join $report_dir check_physical_cts.rpt]
report_clock_tree -summary > [file join $report_dir clock_tree_cts.rpt]
report_qor > [file join $report_dir qor_cts.rpt]
report_timing -max_paths 20 > [file join $report_dir timing_cts.rpt]
save_mw_cel -as cts
create_rectangular_rings -around core -nets {VDD VSS} -left_segment_layer M8 -right_segment_layer M8 -bottom_segment_layer TM1 -top_segment_layer TM1 -left_segment_width 2.0 -right_segment_width 2.0 -bottom_segment_width 2.0 -top_segment_width 2.0 -left_offset 2.0 -right_offset 2.0 -bottom_offset 2.0 -top_offset 2.0
create_power_straps -nets {VDD VSS} -direction vertical -layer M8 -width 1.5 -start_at 20 -num_placement_strap 8 -increment_x_or_y 40
create_power_straps -nets {VDD VSS} -direction horizontal -layer TM1 -width 1.5 -start_at 20 -num_placement_strap 8 -increment_x_or_y 40
insert_stdcell_filler -cell_with_metal {FDCAPVHS64 FDCAPVHS32 FDCAPVHS16 FDCAPVHS8 FDCAPVHS4} -connect_to_power VDD -connect_to_ground VSS
derive_pg_connection -power_net VDD -power_pin VDD -ground_net VSS -ground_pin VSS -reconnect
derive_pg_connection -power_net VDD -power_pin VNW -ground_net VSS -ground_pin VPW -reconnect
preroute_standard_cells -nets {VDD VSS} -connect horizontal -fill_empty_rows -remove_floating_pieces -port_filter_mode off -cell_master_filter_mode off -cell_instance_filter_mode off -voltage_area_filter_mode off
route_opt -effort high
check_legality > [file join $report_dir check_legality_route.rpt]
check_physical_design -stage pre_route_opt > [file join $report_dir check_physical_route.rpt]
report_qor > [file join $report_dir qor_route.rpt]
report_timing -max_paths 20 > [file join $report_dir timing_route.rpt]
report_timing -delay_type min -max_paths 20 > [file join $report_dir timing_hold_route.rpt]
report_congestion -grc_based > [file join $report_dir congestion_route.rpt]
verify_zrt_route > [file join $report_dir verify_route.rpt]
verify_lvs -ignore_floating_port -ignore_floating_net > [file join $report_dir verify_lvs.rpt]
write_verilog -pg [file join $report_dir precoder_core_postroute.v]
write_verilog -no_physical_only_cells [file join $report_dir precoder_core_postroute_sim.v]
write_sdf -version 2.1 [file join $report_dir precoder_core_postroute.sdf]
write_parasitics -output [file join $report_dir precoder_core_postroute.spef]
save_mw_cel -as route
exit
