`timescale 1ns/1ps

module fixed_round_sat #(
    parameter int ACC_WIDTH = 40,
    parameter int IN_FRAC   = 28,
    parameter int OUT_WIDTH = 16,
    parameter int OUT_FRAC  = 14
) (
    input  logic signed [ACC_WIDTH-1:0] acc_i,
    input  logic                        truncate_i,
    input  logic                        wrap_i,
    output logic signed [OUT_WIDTH-1:0] data_o,
    output logic                        saturated_o
);

    localparam int SHIFT = IN_FRAC - OUT_FRAC;
    localparam logic signed [OUT_WIDTH-1:0] OUT_MAX =
        {1'b0, {(OUT_WIDTH-1){1'b1}}};
    localparam logic signed [OUT_WIDTH-1:0] OUT_MIN =
        {1'b1, {(OUT_WIDTH-1){1'b0}}};

    logic signed [ACC_WIDTH:0] acc_ext;
    logic        [ACC_WIDTH:0] magnitude;
    logic        [ACC_WIDTH:0] rounded_magnitude;
    logic signed [ACC_WIDTH:0] rounded_value;
    logic signed [ACC_WIDTH:0] out_max_ext;
    logic signed [ACC_WIDTH:0] out_min_ext;

    initial begin
        if (SHIFT <= 0) $error("IN_FRAC must be greater than OUT_FRAC");
        if (ACC_WIDTH < OUT_WIDTH) $error("ACC_WIDTH must be at least OUT_WIDTH");
    end

    always @(*) begin
        acc_ext = {acc_i[ACC_WIDTH-1], acc_i};
        out_max_ext = {{(ACC_WIDTH+1-OUT_WIDTH){1'b0}}, OUT_MAX};
        out_min_ext = {{(ACC_WIDTH+1-OUT_WIDTH){1'b1}}, OUT_MIN};

        if (acc_ext < 0) begin
            magnitude = $unsigned(-acc_ext);
            rounded_magnitude = (magnitude
                              + ((truncate_i == 1'b1) ? '0
                                 : ({{ACC_WIDTH{1'b0}}, 1'b1} << (SHIFT-1))))
                              >> SHIFT;
            rounded_value = -$signed(rounded_magnitude);
        end else begin
            magnitude = $unsigned(acc_ext);
            rounded_magnitude = (magnitude
                              + ((truncate_i == 1'b1) ? '0
                                 : ({{ACC_WIDTH{1'b0}}, 1'b1} << (SHIFT-1))))
                              >> SHIFT;
            rounded_value = $signed(rounded_magnitude);
        end

        saturated_o = 1'b0;
        if (wrap_i == 1'b1) begin
            data_o = rounded_value[OUT_WIDTH-1:0];
        end else if (rounded_value > out_max_ext) begin
            data_o = OUT_MAX;
            saturated_o = 1'b1;
        end else if (rounded_value < out_min_ext) begin
            data_o = OUT_MIN;
            saturated_o = 1'b1;
        end else begin
            data_o = rounded_value[OUT_WIDTH-1:0];
        end
    end

endmodule
