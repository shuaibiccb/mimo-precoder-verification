`timescale 1ns/1ps

module precoder_core_sva (
    input logic               clk_i,
    input logic               rst_ni,
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

    assert property (p_output_stable_while_stalled)
        else $error("output changed while stalled");
    assert property (p_last_only_on_final_antenna)
        else $error("out_last asserted outside antenna 3");
    assert property (p_reset_clears_visible_state)
        else $error("reset did not clear visible core state");
    assert property (p_active_matrix_stable_during_vector)
        else $error("active matrix changed before the vector boundary");

endmodule

bind precoder_core precoder_core_sva u_precoder_core_sva (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
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
