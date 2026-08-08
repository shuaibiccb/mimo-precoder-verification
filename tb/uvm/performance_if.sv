`timescale 1ns/1ps

interface performance_if(input logic aclk, input logic aresetn);
    logic clear_counters;
    logic input_vector;
    logic output_vector;
    logic input_stall;
    logic output_stall;
    logic saturation;
    logic cfg_write;
    logic commit;
    logic mode_8x8;

    logic [31:0] cycle_count;
    logic [31:0] input_vector_count;
    logic [31:0] output_vector_count;
    logic [31:0] input_stall_count;
    logic [31:0] output_stall_count;
    logic [31:0] saturation_count;
    logic [31:0] cfg_write_count;
    logic [31:0] commit_count;

    logic [31:0] araddr;
    logic arvalid;
    logic arready;
    logic [31:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;
endinterface
