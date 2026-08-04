`timescale 1ns/1ps

module complex_mult #(
    parameter int IN_WIDTH = 16
) (
    input  logic signed [IN_WIDTH-1:0]     a_real_i,
    input  logic signed [IN_WIDTH-1:0]     a_imag_i,
    input  logic signed [IN_WIDTH-1:0]     b_real_i,
    input  logic signed [IN_WIDTH-1:0]     b_imag_i,
    output logic signed [(2*IN_WIDTH):0]   p_real_o,
    output logic signed [(2*IN_WIDTH):0]   p_imag_o
);

    logic signed [(2*IN_WIDTH)-1:0] mul_rr;
    logic signed [(2*IN_WIDTH)-1:0] mul_ii;
    logic signed [(2*IN_WIDTH)-1:0] mul_ri;
    logic signed [(2*IN_WIDTH)-1:0] mul_ir;

    assign mul_rr = a_real_i * b_real_i;
    assign mul_ii = a_imag_i * b_imag_i;
    assign mul_ri = a_real_i * b_imag_i;
    assign mul_ir = a_imag_i * b_real_i;

    // Extend before add/subtract so the complex result keeps its carry bit.
    assign p_real_o = {mul_rr[(2*IN_WIDTH)-1], mul_rr}
                    - {mul_ii[(2*IN_WIDTH)-1], mul_ii};
    assign p_imag_o = {mul_ri[(2*IN_WIDTH)-1], mul_ri}
                    + {mul_ir[(2*IN_WIDTH)-1], mul_ir};

endmodule
