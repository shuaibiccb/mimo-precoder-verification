`timescale 1ns/1ps

module axi_precoder_coverage (
    input logic        aclk,
    input logic        aresetn,
    input logic [3:0]  s_axis_tkeep,
    input logic        s_axis_tvalid,
    input logic        s_axis_tready,
    input logic        s_axis_tlast,
    input logic        m_axis_tvalid,
    input logic        m_axis_tready,
    input logic        m_axis_tlast,
    input logic [10:0] m_axis_tuser,
    input logic        s_axil_awvalid,
    input logic        s_axil_awready,
    input logic [3:0]  s_axil_wstrb,
    input logic        s_axil_wvalid,
    input logic        s_axil_wready,
    input logic [1:0]  s_axil_bresp,
    input logic        s_axil_bvalid,
    input logic        s_axil_bready,
    input logic        s_axil_arvalid,
    input logic        s_axil_arready,
    input logic [1:0]  s_axil_rresp,
    input logic        s_axil_rvalid,
    input logic        s_axil_rready,
    input logic        cfg_valid,
    input logic        cfg_bank,
    input logic        commit_valid,
    input logic        commit_bank,
    input logic        commit_pending,
    input logic        active_bank,
    input logic [7:0]  active_version,
    input logic        early_tlast_pulse,
    input logic        missing_tlast_pulse,
    input logic        invalid_tkeep_pulse,
    input logic        saturation_pulse
);

    covergroup cg_axi_precoder @(posedge aclk);
        option.per_instance = 1;

        cp_write_arrival: coverpoint {
            (s_axil_awvalid && s_axil_awready),
            (s_axil_wvalid && s_axil_wready)
        } iff (aresetn) {
            bins aw_first = {2'b10};
            bins w_first = {2'b01};
            bins together = {2'b11};
        }
        cp_write_response: coverpoint s_axil_bresp
            iff (aresetn && s_axil_bvalid && s_axil_bready) {
            bins okay = {2'b00};
            bins slverr = {2'b10};
        }
        cp_read_response: coverpoint s_axil_rresp
            iff (aresetn && s_axil_rvalid && s_axil_rready) {
            bins okay = {2'b00};
            bins slverr = {2'b10};
        }
        cp_write_strobe: coverpoint s_axil_wstrb
            iff (aresetn && s_axil_wvalid && s_axil_wready) {
            bins full = {4'hf};
            bins partial = {[4'h1:4'he]};
            bins none = {4'h0};
        }
        cp_input_stall: coverpoint (s_axis_tvalid && !s_axis_tready)
            iff (aresetn) { bins seen = {1'b1}; }
        cp_output_stall: coverpoint (m_axis_tvalid && !m_axis_tready)
            iff (aresetn) { bins seen = {1'b1}; }
        cp_input_tlast: coverpoint s_axis_tlast
            iff (aresetn && s_axis_tvalid && s_axis_tready);
        cp_input_tkeep: coverpoint s_axis_tkeep
            iff (aresetn && s_axis_tvalid && s_axis_tready) {
            bins valid = {4'hf};
            bins invalid = {[4'h0:4'he]};
        }
        cp_output_ant: coverpoint m_axis_tuser[1:0]
            iff (aresetn && m_axis_tvalid && m_axis_tready) {
            bins antennas[] = {[0:3]};
        }
        cp_output_last: coverpoint m_axis_tlast
            iff (aresetn && m_axis_tvalid && m_axis_tready);
        cp_output_sat: coverpoint m_axis_tuser[2]
            iff (aresetn && m_axis_tvalid && m_axis_tready);
        cp_cfg_bank: coverpoint cfg_bank iff (aresetn && cfg_valid);
        cp_commit_bank: coverpoint commit_bank iff (aresetn && commit_valid);
        cp_commit_pending: coverpoint commit_pending iff (aresetn);
        cp_active_bank: coverpoint active_bank iff (aresetn);
        cp_version: coverpoint active_version iff (aresetn) {
            bins reset_version = {8'h00};
            bins programmed_version = {[8'h01:8'hff]};
        }
        cp_early_tlast: coverpoint early_tlast_pulse iff (aresetn) {
            bins seen = {1'b1};
        }
        cp_missing_tlast: coverpoint missing_tlast_pulse iff (aresetn) {
            bins seen = {1'b1};
        }
        cp_invalid_tkeep: coverpoint invalid_tkeep_pulse iff (aresetn) {
            bins seen = {1'b1};
        }
        cp_saturation: coverpoint saturation_pulse iff (aresetn) {
            bins seen = {1'b1};
        }
        x_output_boundary: cross cp_output_ant, cp_output_last {
            ignore_bins nonfinal_last = binsof(cp_output_ant) intersect {[0:2]}
                                      && binsof(cp_output_last) intersect {1};
            ignore_bins final_without_last = binsof(cp_output_ant) intersect {3}
                                           && binsof(cp_output_last) intersect {0};
        }
    endgroup

    cg_axi_precoder coverage = new();

endmodule

bind axi_precoder_wrapper axi_precoder_coverage u_axi_precoder_coverage (.*);
