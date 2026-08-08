`timescale 1ns/1ps

interface axi_lite_if(input logic aclk, input logic aresetn);
    logic [31:0] awaddr;
    logic        awvalid;
    logic        awready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;
    logic [31:0] araddr;
    logic        arvalid;
    logic        arready;
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

    modport master(
        input aclk, aresetn, awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid,
        output awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arvalid, rready
    );
    modport slave(
        input aclk, aresetn, awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arvalid, rready,
        output awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid
    );
    modport monitor(
        input aclk, aresetn, awaddr, awvalid, awready, wdata, wstrb, wvalid, wready,
        bresp, bvalid, bready, araddr, arvalid, arready, rdata, rresp, rvalid, rready
    );
endinterface
