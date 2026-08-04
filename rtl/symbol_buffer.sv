`timescale 1ns/1ps

module symbol_buffer #(
    parameter int DATA_WIDTH = 16
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic                         write_en_i,
    input  logic [1:0]                   write_idx_i,
    input  logic signed [DATA_WIDTH-1:0] write_real_i,
    input  logic signed [DATA_WIDTH-1:0] write_imag_i,
    input  logic [1:0]                   read_idx_i,
    output logic signed [DATA_WIDTH-1:0] read_real_o,
    output logic signed [DATA_WIDTH-1:0] read_imag_o
);

    logic signed [DATA_WIDTH-1:0] symbol_real [0:3];
    logic signed [DATA_WIDTH-1:0] symbol_imag [0:3];
    integer idx;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (idx = 0; idx < 4; idx = idx + 1) begin
                symbol_real[idx] <= '0;
                symbol_imag[idx] <= '0;
            end
        end else if (write_en_i) begin
            symbol_real[write_idx_i] <= write_real_i;
            symbol_imag[write_idx_i] <= write_imag_i;
        end
    end

    assign read_real_o = symbol_real[read_idx_i];
    assign read_imag_o = symbol_imag[read_idx_i];

endmodule

