set root_dir [file normalize [file join [file dirname [info script]] ..]]
set timing_root /cad/eda_lib/smic55nm_2020/SCC55NLL_VHS_STDCELL/SCC55NLL_VHS_RVT_lib_V2.1/SCC55NLL_VHS_RVT_V2p1/liberty/1.2v
set target_library [file join $timing_root scc55nll_vhs_rvt_tt_v1p2_25c_basic.db]
set_app_var search_path [list $timing_root]
set_app_var target_library [list $target_library]
set_app_var link_path [concat * $target_library]
read_verilog [file join $root_dir reports generated icc precoder_core_postroute.v]
current_design precoder_core
link
read_sdc [file join $root_dir reports generated dc precoder_core_mapped.sdc]
read_parasitics -format SPEF [file join $root_dir reports generated icc precoder_core_postroute.spef.max]
set_propagated_clock [all_clocks]
update_timing
report_qor > [file join $root_dir reports generated icc pt_postroute_qor.rpt]
report_timing -delay_type max -max_paths 20 > [file join $root_dir reports generated icc pt_postroute_setup.rpt]
report_timing -delay_type min -max_paths 20 > [file join $root_dir reports generated icc pt_postroute_hold.rpt]
report_constraint -all_violators > [file join $root_dir reports generated icc pt_postroute_violations.rpt]
exit
