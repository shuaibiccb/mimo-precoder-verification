`timescale 1ns/1ps

module precoder_core_coverage (
    input logic       clk_i,
    input logic       rst_ni,
    input logic       mode_8x8_i,
    input logic       cfg_valid_i,
    input logic       cfg_ready_o,
    input logic       cfg_bank_i,
    input logic [1:0] bank_complete_o,
    input logic       commit_valid_i,
    input logic       commit_ready_o,
    input logic       commit_bank_i,
    input logic [7:0] commit_version_i,
    input logic       commit_pending_o,
    input logic       active_bank_o,
    input logic [7:0] active_version_o,
    input logic       in_valid_i,
    input logic       in_ready_o,
    input logic       in_last_i,
    input logic       out_valid_o,
    input logic       out_ready_i,
    input logic [2:0] out_ant_idx_o,
    input logic       out_last_o,
    input logic       out_saturated_o,
    input logic [7:0] out_version_o,
    input logic       busy_o,
    input logic       protocol_error_o
);

    covergroup cg_precoder @(posedge clk_i);
        option.per_instance = 1;

        cp_cfg_bank: coverpoint cfg_bank_i iff (rst_ni && cfg_valid_i && cfg_ready_o) {
            bins bank0 = {0};
            bins bank1 = {1};
        }
        cp_mode: coverpoint mode_8x8_i iff (rst_ni) {
            bins mode_4x4 = {0};
            bins mode_8x8 = {1};
        }
        cp_bank_complete: coverpoint bank_complete_o iff (rst_ni) {
            bins empty = {2'b00};
            bins bank0_only = {2'b01};
            bins bank1_only = {2'b10};
            bins both = {2'b11};
        }
        cp_commit_bank: coverpoint commit_bank_i iff (rst_ni && commit_valid_i && commit_ready_o) {
            bins bank0 = {0};
            bins bank1 = {1};
        }
        cp_commit_busy: coverpoint busy_o iff (rst_ni && commit_valid_i && commit_ready_o) {
            bins idle = {0};
            bins busy = {1};
        }
        cp_commit_version: coverpoint commit_version_i iff (rst_ni && commit_valid_i && commit_ready_o) {
            bins zero = {8'h00};
            bins low_nonzero = {[8'h01:8'h7f]};
            bins high_nonzero = {[8'h80:8'hff]};
        }
        cp_pending: coverpoint commit_pending_o iff (rst_ni) {
            bins not_pending = {0};
            bins pending = {1};
        }
        cp_active_bank: coverpoint active_bank_o iff (rst_ni) {
            bins bank0 = {0};
            bins bank1 = {1};
            bins switch_0_to_1 = (0 => 1);
            bins switch_1_to_0 = (1 => 0);
        }
        cp_input_position: coverpoint in_last_i iff (rst_ni && in_valid_i && in_ready_o) {
            bins body = {0};
            bins last = {1};
        }
        cp_backpressure: coverpoint (out_valid_o && !out_ready_i) iff (rst_ni) {
            bins no_stall = {0};
            bins stalled = {1};
        }
        cp_output_ant: coverpoint out_ant_idx_o iff (rst_ni && out_valid_o && out_ready_i) {
            bins antennas[] = {[0:7]};
        }
        cp_output_last: coverpoint out_last_o iff (rst_ni && out_valid_o && out_ready_i) {
            bins body = {0};
            bins last = {1};
        }
        cp_saturation: coverpoint out_saturated_o iff (rst_ni && out_valid_o && out_ready_i) {
            bins normal = {0};
            bins saturated = {1};
        }
        cp_output_version: coverpoint out_version_o iff (rst_ni && out_valid_o && out_ready_i) {
            bins initial_version = {8'h00};
            bins low_updated = {[8'h01:8'h7f]};
            bins high_updated = {[8'h80:8'hff]};
        }
        cp_protocol_error: coverpoint protocol_error_o iff (rst_ni) {
            bins clean = {0};
            bins error = {1};
        }

        cross_commit_context: cross cp_commit_bank, cp_commit_busy;
        cross_mode_output: cross cp_mode, cp_output_ant;
    endgroup

    cg_precoder coverage = new();

endmodule

bind precoder_core precoder_core_coverage u_precoder_core_coverage (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .mode_8x8_i(mode_8x8_i),
    .cfg_valid_i(cfg_valid_i),
    .cfg_ready_o(cfg_ready_o),
    .cfg_bank_i(cfg_bank_i),
    .bank_complete_o(bank_complete_o),
    .commit_valid_i(commit_valid_i),
    .commit_ready_o(commit_ready_o),
    .commit_bank_i(commit_bank_i),
    .commit_version_i(commit_version_i),
    .commit_pending_o(commit_pending_o),
    .active_bank_o(active_bank_o),
    .active_version_o(active_version_o),
    .in_valid_i(in_valid_i),
    .in_ready_o(in_ready_o),
    .in_last_i(in_last_i),
    .out_valid_o(out_valid_o),
    .out_ready_i(out_ready_i),
    .out_ant_idx_o(out_ant_idx_o),
    .out_last_o(out_last_o),
    .out_saturated_o(out_saturated_o),
    .out_version_o(out_version_o),
    .busy_o(busy_o),
    .protocol_error_o(protocol_error_o)
);
