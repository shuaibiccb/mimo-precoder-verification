`timescale 1ns/1ps

module complex_mac #(
    parameter int IN_WIDTH  = 16,
    parameter int ACC_WIDTH = 40
) (
    input  logic                            clk_i,
    input  logic                            rst_ni,
    input  logic                            clear_i,
    input  logic                            enable_i,
    input  logic signed [IN_WIDTH-1:0]      a_real_i,
    input  logic signed [IN_WIDTH-1:0]      a_imag_i,
    input  logic signed [IN_WIDTH-1:0]      b_real_i,
    input  logic signed [IN_WIDTH-1:0]      b_imag_i,
    output logic signed [ACC_WIDTH-1:0]     acc_real_o,
    output logic signed [ACC_WIDTH-1:0]     acc_imag_o
);

    localparam int PRODUCT_WIDTH = (2 * IN_WIDTH) + 1;

    logic signed [PRODUCT_WIDTH-1:0] product_real;
    logic signed [PRODUCT_WIDTH-1:0] product_imag;
    logic signed [ACC_WIDTH-1:0]     product_real_ext;
    logic signed [ACC_WIDTH-1:0]     product_imag_ext;

    initial begin
        if (ACC_WIDTH < PRODUCT_WIDTH) begin
            $error("ACC_WIDTH must be at least PRODUCT_WIDTH");
        end
    end

    complex_mult #(
        .IN_WIDTH(IN_WIDTH)
    ) u_complex_mult (
        .a_real_i(a_real_i),
        .a_imag_i(a_imag_i),
        .b_real_i(b_real_i),
        .b_imag_i(b_imag_i),
        .p_real_o(product_real),
        .p_imag_o(product_imag)
    );

    assign product_real_ext =
        {{(ACC_WIDTH-PRODUCT_WIDTH){product_real[PRODUCT_WIDTH-1]}}, product_real};
    assign product_imag_ext =
        {{(ACC_WIDTH-PRODUCT_WIDTH){product_imag[PRODUCT_WIDTH-1]}}, product_imag};

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            acc_real_o <= '0;
            acc_imag_o <= '0;
        end else if (clear_i) begin
            acc_real_o <= '0;
            acc_imag_o <= '0;
        end else if (enable_i) begin
            acc_real_o <= acc_real_o + product_real_ext;
            acc_imag_o <= acc_imag_o + product_imag_ext;
        end
    end

endmodule
