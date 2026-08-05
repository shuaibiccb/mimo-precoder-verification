`timescale 1ns/1ps

module matrix_storage #(
    parameter int DATA_WIDTH = 16
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic                         write_en_i,
    input  logic                         write_bank_i,
    input  logic [1:0]                   write_row_i,
    input  logic [1:0]                   write_col_i,
    input  logic signed [DATA_WIDTH-1:0] write_real_i,
    input  logic signed [DATA_WIDTH-1:0] write_imag_i,
    input  logic                         read_bank_i,
    input  logic [1:0]                   read_col_i,
    output logic signed [DATA_WIDTH-1:0] row0_real_o,
    output logic signed [DATA_WIDTH-1:0] row0_imag_o,
    output logic signed [DATA_WIDTH-1:0] row1_real_o,
    output logic signed [DATA_WIDTH-1:0] row1_imag_o,
    output logic signed [DATA_WIDTH-1:0] row2_real_o,
    output logic signed [DATA_WIDTH-1:0] row2_imag_o,
    output logic signed [DATA_WIDTH-1:0] row3_real_o,
    output logic signed [DATA_WIDTH-1:0] row3_imag_o,
    output logic [1:0]                   complete_o
);

    logic signed [DATA_WIDTH-1:0] matrix_real [0:1][0:3][0:3];
    logic signed [DATA_WIDTH-1:0] matrix_imag [0:1][0:3][0:3];
    logic [15:0]                  written_mask [0:1];
    integer bank;
    integer row;
    integer col;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            written_mask[0] <= '0;
            written_mask[1] <= '0;
            for (bank = 0; bank < 2; bank = bank + 1) begin
                for (row = 0; row < 4; row = row + 1) begin
                    for (col = 0; col < 4; col = col + 1) begin
                        matrix_real[bank][row][col] <= '0;
                        matrix_imag[bank][row][col] <= '0;
                    end
                end
            end
        end else if (write_en_i) begin
            matrix_real[write_bank_i][write_row_i][write_col_i] <= write_real_i;
            matrix_imag[write_bank_i][write_row_i][write_col_i] <= write_imag_i;
            written_mask[write_bank_i][{write_row_i, write_col_i}] <= 1'b1;
        end
    end

    assign row0_real_o = matrix_real[read_bank_i][0][read_col_i];
    assign row0_imag_o = matrix_imag[read_bank_i][0][read_col_i];
    assign row1_real_o = matrix_real[read_bank_i][1][read_col_i];
    assign row1_imag_o = matrix_imag[read_bank_i][1][read_col_i];
    assign row2_real_o = matrix_real[read_bank_i][2][read_col_i];
    assign row2_imag_o = matrix_imag[read_bank_i][2][read_col_i];
    assign row3_real_o = matrix_real[read_bank_i][3][read_col_i];
    assign row3_imag_o = matrix_imag[read_bank_i][3][read_col_i];
    assign complete_o[0] = &written_mask[0];
    assign complete_o[1] = &written_mask[1];

endmodule

