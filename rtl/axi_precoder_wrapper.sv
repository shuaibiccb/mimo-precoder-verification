`timescale 1ns/1ps

module axi_precoder_wrapper #(
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH = 40,
    parameter int VERSION_WIDTH = 8
) (
    input logic aclk,
    input logic aresetn,

    input logic [31:0] s_axis_tdata,
    input logic [3:0] s_axis_tkeep,
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic s_axis_tlast,
    output logic [31:0] m_axis_tdata,
    output logic [3:0] m_axis_tkeep,
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic m_axis_tlast,
    output logic [11:0] m_axis_tuser,

    input logic [31:0] s_axil_awaddr,
    input logic s_axil_awvalid,
    output logic s_axil_awready,
    input logic [31:0] s_axil_wdata,
    input logic [3:0] s_axil_wstrb,
    input logic s_axil_wvalid,
    output logic s_axil_wready,
    output logic [1:0] s_axil_bresp,
    output logic s_axil_bvalid,
    input logic s_axil_bready,
    input logic [31:0] s_axil_araddr,
    input logic s_axil_arvalid,
    output logic s_axil_arready,
    output logic [31:0] s_axil_rdata,
    output logic [1:0] s_axil_rresp,
    output logic s_axil_rvalid,
    input logic s_axil_rready
);

    logic cfg_valid, cfg_ready, cfg_bank;
    logic [2:0] cfg_row, cfg_col;
    logic mode_8x8;
    logic format_12;
    logic format_change;
    logic signed [DATA_WIDTH-1:0] cfg_real, cfg_imag;
    logic [1:0] bank_complete;
    logic matrix_complete;
    logic commit_valid, commit_ready, commit_bank;
    logic [VERSION_WIDTH-1:0] commit_version;
    logic commit_pending, active_bank;
    logic [VERSION_WIDTH-1:0] active_version;
    logic in_valid, in_ready, in_last;
    logic signed [DATA_WIDTH-1:0] in_real, in_imag;
    logic out_valid, out_ready, out_last, out_saturated;
    logic signed [DATA_WIDTH-1:0] out_real, out_imag;
    logic [2:0] out_ant_idx;
    logic [VERSION_WIDTH-1:0] out_version;
    logic busy, protocol_error;
    logic input_vector_pulse, early_tlast_pulse, missing_tlast_pulse;
    logic invalid_tkeep_pulse, output_vector_pulse, saturation_pulse;
    logic clear_counters, cfg_write_pulse, commit_pulse;
    logic [7:0] error_status;
    logic [31:0] cycle_count, input_vector_count, output_vector_count;
    logic [31:0] input_stall_count, output_stall_count, saturation_count;
    logic [31:0] cfg_write_count, commit_count;

    axi_stream_input u_stream_input (
        .aclk(aclk), .aresetn(aresetn),
        .mode_8x8_i(mode_8x8),
        .s_axis_tdata(s_axis_tdata), .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast), .core_valid_o(in_valid),
        .core_ready_i(in_ready), .core_real_o(in_real), .core_imag_o(in_imag),
        .core_last_o(in_last), .input_vector_pulse_o(input_vector_pulse),
        .early_tlast_pulse_o(early_tlast_pulse),
        .missing_tlast_pulse_o(missing_tlast_pulse),
        .invalid_tkeep_pulse_o(invalid_tkeep_pulse)
    );

    axi_stream_output u_stream_output (
        .core_valid_i(out_valid), .core_ready_o(out_ready),
        .core_real_i(out_real), .core_imag_i(out_imag),
        .core_ant_idx_i(out_ant_idx), .core_last_i(out_last),
        .core_saturated_i(out_saturated), .core_version_i(out_version),
        .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast), .m_axis_tuser(m_axis_tuser),
        .output_vector_pulse_o(output_vector_pulse),
        .saturation_pulse_o(saturation_pulse)
    );

    axi_lite_regs u_axi_lite_regs (
        .aclk(aclk), .aresetn(aresetn),
        .s_axil_awaddr(s_axil_awaddr), .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready), .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb), .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready), .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid), .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr), .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready), .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp), .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready), .cfg_valid_o(cfg_valid),
        .cfg_ready_i(cfg_ready), .cfg_bank_o(cfg_bank), .cfg_row_o(cfg_row),
        .cfg_col_o(cfg_col), .cfg_real_o(cfg_real), .cfg_imag_o(cfg_imag),
        .mode_8x8_o(mode_8x8),
        .format_12_o(format_12), .format_change_o(format_change),
        .commit_valid_o(commit_valid), .commit_ready_i(commit_ready),
        .commit_bank_o(commit_bank), .commit_version_o(commit_version),
        .busy_i(busy), .matrix_complete_i(matrix_complete),
        .bank_complete_i(bank_complete), .commit_pending_i(commit_pending),
        .active_bank_i(active_bank), .active_version_i(active_version),
        .core_protocol_error_i(protocol_error),
        .input_early_tlast_i(early_tlast_pulse),
        .input_missing_tlast_i(missing_tlast_pulse),
        .input_invalid_tkeep_i(invalid_tkeep_pulse),
        .cycle_count_i(cycle_count), .input_vector_count_i(input_vector_count),
        .output_vector_count_i(output_vector_count),
        .input_stall_count_i(input_stall_count),
        .output_stall_count_i(output_stall_count),
        .saturation_count_i(saturation_count),
        .cfg_write_count_i(cfg_write_count), .commit_count_i(commit_count),
        .clear_counters_o(clear_counters), .cfg_write_pulse_o(cfg_write_pulse),
        .commit_pulse_o(commit_pulse), .error_status_o(error_status)
    );

    performance_counters u_performance_counters (
        .aclk(aclk), .aresetn(aresetn), .clear_i(clear_counters),
        .input_vector_i(input_vector_pulse), .output_vector_i(output_vector_pulse),
        .input_stall_i(s_axis_tvalid && !s_axis_tready),
        .output_stall_i(m_axis_tvalid && !m_axis_tready),
        .saturation_i(saturation_pulse), .cfg_write_i(cfg_write_pulse),
        .commit_i(commit_pulse), .cycle_count_o(cycle_count),
        .input_vector_count_o(input_vector_count),
        .output_vector_count_o(output_vector_count),
        .input_stall_count_o(input_stall_count),
        .output_stall_count_o(output_stall_count),
        .saturation_count_o(saturation_count),
        .cfg_write_count_o(cfg_write_count), .commit_count_o(commit_count)
    );

    precoder_core #(
        .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH),
        .VERSION_WIDTH(VERSION_WIDTH)
    ) u_precoder_core (
        .clk_i(aclk), .rst_ni(aresetn),
        .mode_8x8_i(mode_8x8),
        .format_12_i(format_12), .format_change_i(format_change),
        .cfg_valid_i(cfg_valid), .cfg_ready_o(cfg_ready), .cfg_bank_i(cfg_bank),
        .cfg_row_i(cfg_row), .cfg_col_i(cfg_col), .cfg_real_i(cfg_real),
        .cfg_imag_i(cfg_imag), .bank_complete_o(bank_complete),
        .matrix_complete_o(matrix_complete), .commit_valid_i(commit_valid),
        .commit_ready_o(commit_ready), .commit_bank_i(commit_bank),
        .commit_version_i(commit_version), .commit_pending_o(commit_pending),
        .active_bank_o(active_bank), .active_version_o(active_version),
        .in_valid_i(in_valid), .in_ready_o(in_ready), .in_real_i(in_real),
        .in_imag_i(in_imag), .in_last_i(in_last), .out_valid_o(out_valid),
        .out_ready_i(out_ready), .out_real_o(out_real), .out_imag_o(out_imag),
        .out_ant_idx_o(out_ant_idx), .out_last_o(out_last),
        .out_saturated_o(out_saturated), .out_version_o(out_version),
        .busy_o(busy), .protocol_error_o(protocol_error)
    );

endmodule
