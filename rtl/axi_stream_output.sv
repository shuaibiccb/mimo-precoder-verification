`timescale 1ns/1ps

module axi_stream_output (
    input  logic        core_valid_i,
    output logic        core_ready_o,
    input  logic signed [15:0] core_real_i,
    input  logic signed [15:0] core_imag_i,
    input  logic [1:0]  core_ant_idx_i,
    input  logic        core_last_i,
    input  logic        core_saturated_i,
    input  logic [7:0]  core_version_i,

    output logic [31:0] m_axis_tdata,
    output logic [3:0]  m_axis_tkeep,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    output logic        m_axis_tlast,
    output logic [10:0] m_axis_tuser,

    output logic        output_vector_pulse_o,
    output logic        saturation_pulse_o
);

    logic handshake;

    assign core_ready_o = m_axis_tready;
    assign m_axis_tdata = {core_real_i, core_imag_i};
    assign m_axis_tkeep = 4'b1111;
    assign m_axis_tvalid = core_valid_i;
    assign m_axis_tlast = core_last_i;
    assign m_axis_tuser = {core_version_i, core_saturated_i, core_ant_idx_i};

    assign handshake = m_axis_tvalid && m_axis_tready;
    assign output_vector_pulse_o = handshake && m_axis_tlast;
    assign saturation_pulse_o = handshake && core_saturated_i;

endmodule
