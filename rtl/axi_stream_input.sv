`timescale 1ns/1ps

module axi_stream_input (
    input  logic        aclk,
    input  logic        aresetn,
    input  logic        mode_8x8_i,

    input  logic [31:0] s_axis_tdata,
    input  logic [3:0]  s_axis_tkeep,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tlast,

    output logic        core_valid_o,
    input  logic        core_ready_i,
    output logic signed [15:0] core_real_o,
    output logic signed [15:0] core_imag_o,
    output logic        core_last_o,

    output logic        input_vector_pulse_o,
    output logic        early_tlast_pulse_o,
    output logic        missing_tlast_pulse_o,
    output logic        invalid_tkeep_pulse_o
);

    logic [2:0] beat_index;
    logic [2:0] final_index;
    logic       handshake;

    assign core_valid_o = s_axis_tvalid;
    assign s_axis_tready = core_ready_i;
    assign core_real_o = s_axis_tdata[31:16];
    assign core_imag_o = s_axis_tdata[15:0];
    assign core_last_o = s_axis_tlast;
    assign handshake = s_axis_tvalid && s_axis_tready;

    assign final_index = mode_8x8_i ? 3'd7 : 3'd3;
    assign input_vector_pulse_o = handshake && (beat_index == final_index);
    assign early_tlast_pulse_o = handshake && s_axis_tlast
                                && (beat_index != final_index);
    assign missing_tlast_pulse_o = handshake && !s_axis_tlast
                                  && (beat_index == final_index);
    assign invalid_tkeep_pulse_o = handshake && (s_axis_tkeep != 4'b1111);

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            beat_index <= 3'd0;
        end else if (handshake) begin
            if (beat_index == final_index) begin
                beat_index <= 3'd0;
            end else begin
                beat_index <= beat_index + 1'b1;
            end
        end
    end

endmodule
