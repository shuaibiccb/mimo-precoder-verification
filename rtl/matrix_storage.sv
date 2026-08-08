`timescale 1ns/1ps

module matrix_storage #(
    parameter int DATA_WIDTH = 16
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic                         mode_8x8_i,
    input  logic                         format_change_i,
    input  logic                         write_en_i,
    input  logic                         write_bank_i,
    input  logic [2:0]                   write_row_i,
    input  logic [2:0]                   write_col_i,
    input  logic signed [DATA_WIDTH-1:0] write_real_i,
    input  logic signed [DATA_WIDTH-1:0] write_imag_i,
    input  logic                         read_bank_i,
    input  logic                         read_row_group_i,
    input  logic [2:0]                   read_col_i,
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

    logic signed [DATA_WIDTH-1:0] matrix_real [0:1][0:7][0:7];
    logic signed [DATA_WIDTH-1:0] matrix_imag [0:1][0:7][0:7];
    logic [63:0]                  written_mask [0:1];
    logic [1:0]                   complete_4x4;
    logic [2:0]                   read_row_base;
    integer bank;
    integer row;
    integer col;
    integer complete_bank;
    integer complete_row;
    integer complete_col;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            written_mask[0] <= '0;
            written_mask[1] <= '0;
            for (bank = 0; bank < 2; bank = bank + 1) begin
                for (row = 0; row < 8; row = row + 1) begin
                    for (col = 0; col < 8; col = col + 1) begin
                        matrix_real[bank][row][col] <= '0;
                        matrix_imag[bank][row][col] <= '0;
                    end
                end
            end
        end else if (format_change_i) begin
            written_mask[0] <= '0;
            written_mask[1] <= '0;
        end else if (write_en_i) begin
            matrix_real[write_bank_i][write_row_i][write_col_i] <= write_real_i;
            matrix_imag[write_bank_i][write_row_i][write_col_i] <= write_imag_i;
            written_mask[write_bank_i][{write_row_i, write_col_i}] <= 1'b1;
        end
    end

    always_comb begin
        complete_4x4 = 2'b11;
        for (complete_bank = 0; complete_bank < 2; complete_bank = complete_bank + 1) begin
            for (complete_row = 0; complete_row < 4; complete_row = complete_row + 1) begin
                for (complete_col = 0; complete_col < 4; complete_col = complete_col + 1) begin
                    complete_4x4[complete_bank] = complete_4x4[complete_bank]
                                               && written_mask[complete_bank][complete_row*8+complete_col];
                end
            end
        end
    end

    assign read_row_base = read_row_group_i ? 3'd4 : 3'd0;
    assign row0_real_o = matrix_real[read_bank_i][read_row_base][read_col_i];
    assign row0_imag_o = matrix_imag[read_bank_i][read_row_base][read_col_i];
    assign row1_real_o = matrix_real[read_bank_i][read_row_base+3'd1][read_col_i];
    assign row1_imag_o = matrix_imag[read_bank_i][read_row_base+3'd1][read_col_i];
    assign row2_real_o = matrix_real[read_bank_i][read_row_base+3'd2][read_col_i];
    assign row2_imag_o = matrix_imag[read_bank_i][read_row_base+3'd2][read_col_i];
    assign row3_real_o = matrix_real[read_bank_i][read_row_base+3'd3][read_col_i];
    assign row3_imag_o = matrix_imag[read_bank_i][read_row_base+3'd3][read_col_i];
    assign complete_o[0] = mode_8x8_i ? &written_mask[0] : complete_4x4[0];
    assign complete_o[1] = mode_8x8_i ? &written_mask[1] : complete_4x4[1];

endmodule
