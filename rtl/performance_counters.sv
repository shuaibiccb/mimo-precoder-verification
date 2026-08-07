`timescale 1ns/1ps

module performance_counters (
    input  logic        aclk,
    input  logic        aresetn,
    input  logic        clear_i,
    input  logic        input_vector_i,
    input  logic        output_vector_i,
    input  logic        input_stall_i,
    input  logic        output_stall_i,
    input  logic        saturation_i,
    input  logic        cfg_write_i,
    input  logic        commit_i,
    output logic [31:0] cycle_count_o,
    output logic [31:0] input_vector_count_o,
    output logic [31:0] output_vector_count_o,
    output logic [31:0] input_stall_count_o,
    output logic [31:0] output_stall_count_o,
    output logic [31:0] saturation_count_o,
    output logic [31:0] cfg_write_count_o,
    output logic [31:0] commit_count_o
);

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            cycle_count_o         <= 32'd0;
            input_vector_count_o  <= 32'd0;
            output_vector_count_o <= 32'd0;
            input_stall_count_o   <= 32'd0;
            output_stall_count_o  <= 32'd0;
            saturation_count_o    <= 32'd0;
            cfg_write_count_o     <= 32'd0;
            commit_count_o        <= 32'd0;
        end else if (clear_i) begin
            cycle_count_o         <= 32'd0;
            input_vector_count_o  <= 32'd0;
            output_vector_count_o <= 32'd0;
            input_stall_count_o   <= 32'd0;
            output_stall_count_o  <= 32'd0;
            saturation_count_o    <= 32'd0;
            cfg_write_count_o     <= 32'd0;
            commit_count_o        <= 32'd0;
        end else begin
            cycle_count_o <= cycle_count_o + 1'b1;
            if (input_vector_i)
                input_vector_count_o <= input_vector_count_o + 1'b1;
            if (output_vector_i)
                output_vector_count_o <= output_vector_count_o + 1'b1;
            if (input_stall_i)
                input_stall_count_o <= input_stall_count_o + 1'b1;
            if (output_stall_i)
                output_stall_count_o <= output_stall_count_o + 1'b1;
            if (saturation_i)
                saturation_count_o <= saturation_count_o + 1'b1;
            if (cfg_write_i)
                cfg_write_count_o <= cfg_write_count_o + 1'b1;
            if (commit_i)
                commit_count_o <= commit_count_o + 1'b1;
        end
    end

endmodule
