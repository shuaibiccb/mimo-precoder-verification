`timescale 1ns/1ps

interface axi_stream_if(input logic aclk, input logic aresetn);
    logic [31:0] tdata;
    logic [3:0]  tkeep;
    logic        tvalid;
    logic        tready;
    logic        tlast;
    logic [11:0] tuser;

    modport source(
        input  aclk, aresetn, tready,
        output tdata, tkeep, tvalid, tlast, tuser
    );
    modport sink(
        input  aclk, aresetn, tdata, tkeep, tvalid, tlast, tuser,
        output tready
    );
    modport monitor(
        input aclk, aresetn, tdata, tkeep, tvalid, tready, tlast, tuser
    );
endinterface
