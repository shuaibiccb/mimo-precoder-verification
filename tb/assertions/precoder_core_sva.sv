`timescale 1ns/1ps

module precoder_core_sva (
    input logic               clk_i,
    input logic               rst_ni,
    input logic               cfg_valid_i,
    input logic               cfg_ready_o,
    input logic               cfg_bank_i,
    input logic [1:0]         cfg_row_i,
    input logic [1:0]         cfg_col_i,
    input logic signed [15:0] cfg_real_i,
    input logic signed [15:0] cfg_imag_i,
    input logic [1:0]         bank_complete_o,
    input logic               commit_valid_i,
    input logic               commit_ready_o,
    input logic               commit_bank_i,
    input logic [7:0]         commit_version_i,
    input logic               commit_pending_o,
    input logic               in_valid_i,
    input logic               in_ready_o,
    input logic signed [15:0] in_real_i,
    input logic signed [15:0] in_imag_i,
    input logic               in_last_i,
    input logic               out_valid_o,
    input logic               out_ready_i,
    input logic signed [15:0] out_real_o,
    input logic signed [15:0] out_imag_o,
    input logic [1:0]         out_ant_idx_o,
    input logic               out_last_o,
    input logic               out_saturated_o,
    input logic [7:0]         out_version_o,
    input logic               active_bank_o,
    input logic [7:0]         active_version_o,
    input logic               busy_o
);

    property p_output_stable_while_stalled;
        @(posedge clk_i) disable iff (!rst_ni)
            out_valid_o && !out_ready_i
            |=> out_valid_o && $stable({out_real_o, out_imag_o, out_ant_idx_o,
                                        out_last_o, out_saturated_o, out_version_o});
    endproperty

    property p_cfg_stable_while_stalled;
        @(posedge clk_i) disable iff (!rst_ni)
            cfg_valid_i && !cfg_ready_o
            |=> cfg_valid_i && $stable({cfg_bank_i, cfg_row_i, cfg_col_i,
                                        cfg_real_i, cfg_imag_i});
    endproperty

    property p_input_stable_while_stalled;
        @(posedge clk_i) disable iff (!rst_ni)
            in_valid_i && !in_ready_o
            |=> in_valid_i && $stable({in_real_i, in_imag_i, in_last_i});
    endproperty

    property p_commit_stable_while_stalled;
        @(posedge clk_i) disable iff (!rst_ni)
            commit_valid_i && !commit_ready_o
                && !$past(commit_valid_i && commit_ready_o)
            |=> commit_valid_i && $stable({commit_bank_i, commit_version_i});
    endproperty

    property p_last_only_on_final_antenna;
        @(posedge clk_i) disable iff (!rst_ni)
            out_last_o |-> out_valid_o && (out_ant_idx_o == 2'd3);
    endproperty

    property p_reset_clears_visible_state;
        @(posedge clk_i)
            !rst_ni |-> !out_valid_o && !busy_o;
    endproperty

    property p_active_matrix_stable_during_vector;
        @(posedge clk_i) disable iff (!rst_ni)
            busy_o && !(out_valid_o && out_ready_i && out_last_o)
            |=> $stable({active_bank_o, active_version_o});
    endproperty

    property p_no_active_bank_write_while_busy;
        @(posedge clk_i) disable iff (!rst_ni)
            cfg_valid_i && cfg_ready_o && busy_o |-> cfg_bank_i != active_bank_o;
    endproperty

    property p_commit_targets_complete_inactive_bank;
        @(posedge clk_i) disable iff (!rst_ni)
            commit_valid_i && commit_ready_o
            |-> bank_complete_o[commit_bank_i] && (commit_bank_i != active_bank_o);
    endproperty

    property p_pending_clears_only_at_vector_boundary;
        @(posedge clk_i) disable iff (!rst_ni)
            commit_pending_o && !commit_valid_i
                && !(out_valid_o && out_ready_i && out_last_o)
            |=> commit_pending_o;
    endproperty

    property p_final_antenna_has_last;
        @(posedge clk_i) disable iff (!rst_ni)
            out_valid_o && (out_ant_idx_o == 2'd3) |-> out_last_o;
    endproperty

    assert property (p_output_stable_while_stalled)
        else $error("output changed while stalled");
    assert property (p_cfg_stable_while_stalled)
        else $error("configuration payload changed while stalled");
    assert property (p_input_stable_while_stalled)
        else $error("input payload changed while stalled");
    assert property (p_commit_stable_while_stalled)
        else $error("commit payload changed while stalled");
    assert property (p_last_only_on_final_antenna)
        else $error("out_last asserted outside antenna 3");
    assert property (p_reset_clears_visible_state)
        else $error("reset did not clear visible core state");
    assert property (p_active_matrix_stable_during_vector)
        else $error("active matrix changed before the vector boundary");
    assert property (p_no_active_bank_write_while_busy)
        else $error("active matrix bank was written while busy");
    assert property (p_commit_targets_complete_inactive_bank)
        else $error("commit accepted for an incomplete or active bank");
    assert property (p_pending_clears_only_at_vector_boundary)
        else $error("pending commit cleared before the vector boundary");
    assert property (p_final_antenna_has_last)
        else $error("antenna 3 output missing out_last");

endmodule

bind precoder_core precoder_core_sva u_precoder_core_sva (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .cfg_valid_i(cfg_valid_i),
    .cfg_ready_o(cfg_ready_o),
    .cfg_bank_i(cfg_bank_i),
    .cfg_row_i(cfg_row_i),
    .cfg_col_i(cfg_col_i),
    .cfg_real_i(cfg_real_i),
    .cfg_imag_i(cfg_imag_i),
    .bank_complete_o(bank_complete_o),
    .commit_valid_i(commit_valid_i),
    .commit_ready_o(commit_ready_o),
    .commit_bank_i(commit_bank_i),
    .commit_version_i(commit_version_i),
    .commit_pending_o(commit_pending_o),
    .in_valid_i(in_valid_i),
    .in_ready_o(in_ready_o),
    .in_real_i(in_real_i),
    .in_imag_i(in_imag_i),
    .in_last_i(in_last_i),
    .out_valid_o(out_valid_o),
    .out_ready_i(out_ready_i),
    .out_real_o(out_real_o),
    .out_imag_o(out_imag_o),
    .out_ant_idx_o(out_ant_idx_o),
    .out_last_o(out_last_o),
    .out_saturated_o(out_saturated_o),
    .out_version_o(out_version_o),
    .active_bank_o(active_bank_o),
    .active_version_o(active_version_o),
    .busy_o(busy_o)
);
