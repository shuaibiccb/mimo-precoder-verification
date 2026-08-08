`timescale 1ns/1ps

module tb_axi_precoder_stress;
    localparam logic [1:0] OKAY = 2'b00;
    localparam logic [1:0] SLVERR = 2'b10;
    logic aclk = 1'b0;
    logic aresetn = 1'b0;
    always #5 aclk = ~aclk;

    logic [31:0] s_axis_tdata, m_axis_tdata, awaddr, wdata, araddr, rdata;
    logic [3:0] s_axis_tkeep, m_axis_tkeep, wstrb;
    logic s_axis_tvalid, s_axis_tready, s_axis_tlast;
    logic m_axis_tvalid, m_axis_tready, m_axis_tlast;
    logic awvalid, awready, wvalid, wready, bvalid, bready;
    logic arvalid, arready, rvalid, rready;
    logic [1:0] bresp, rresp;
    logic [11:0] m_axis_tuser;

    axi_precoder_wrapper dut (
        .aclk(aclk), .aresetn(aresetn), .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast), .m_axis_tuser(m_axis_tuser),
        .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
        .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid),
        .s_axil_wready(wready), .s_axil_bresp(bresp), .s_axil_bvalid(bvalid),
        .s_axil_bready(bready), .s_axil_araddr(araddr), .s_axil_arvalid(arvalid),
        .s_axil_arready(arready), .s_axil_rdata(rdata), .s_axil_rresp(rresp),
        .s_axil_rvalid(rvalid), .s_axil_rready(rready)
    );

    task automatic lite_write(input logic [31:0] addr, input logic [31:0] data,
                              input logic [3:0] strb, input logic w_first,
                              input logic [1:0] expected);
        begin
            @(negedge aclk);
            if (w_first) begin
                wdata=data; wstrb=strb; wvalid=1'b1;
                do @(posedge aclk); while (!wready);
                @(negedge aclk); wvalid=1'b0;
                @(negedge aclk); awaddr=addr; awvalid=1'b1;
                do @(posedge aclk); while (!awready);
                @(negedge aclk); awvalid=1'b0;
            end else begin
                awaddr=addr; awvalid=1'b1;
                do @(posedge aclk); while (!awready);
                @(negedge aclk); awvalid=1'b0;
                @(negedge aclk); wdata=data; wstrb=strb; wvalid=1'b1;
                do @(posedge aclk); while (!wready);
                @(negedge aclk); wvalid=1'b0;
            end
            do @(posedge aclk); while (!bvalid);
            if (bresp !== expected) $fatal(1,"write %08x resp %b",addr,bresp);
            @(negedge aclk);
        end
    endtask

    task automatic lite_read(input logic [31:0] addr, input logic [1:0] expected,
                             output logic [31:0] data);
        begin
            @(negedge aclk); araddr=addr; arvalid=1'b1;
            do @(posedge aclk); while (!arready);
            @(negedge aclk); arvalid=1'b0;
            do @(posedge aclk); while (!rvalid);
            data=rdata;
            if (rresp !== expected) $fatal(1,"read %08x resp %b",addr,rresp);
            @(negedge aclk);
        end
    endtask

    task automatic configure_identity;
        integer i;
        logic [31:0] addr, coeff;
        begin
            for (i=0;i<16;i=i+1) begin
                addr=32'h100+i*4;
                coeff=((i/4)==(i%4)) ? 32'h4000_0000 : 32'd0;
                lite_write(addr,coeff,4'hf,i[0],OKAY);
            end
        end
    endtask

    task automatic send_beat(input logic [31:0] data, input logic [3:0] keep,
                             input logic last);
        begin
            @(negedge aclk);
            s_axis_tdata=data; s_axis_tkeep=keep; s_axis_tlast=last;
            s_axis_tvalid=1'b1;
            do @(posedge aclk); while (!s_axis_tready);
            @(negedge aclk); s_axis_tvalid=1'b0;
        end
    endtask

    logic [31:0] rd, held_rdata;
    logic [1:0] held_bresp;
    integer i, seed;
    initial begin
        s_axis_tdata='0; s_axis_tkeep=4'hf; s_axis_tvalid=0; s_axis_tlast=0;
        m_axis_tready=1; awaddr='0; awvalid=0; wdata='0; wstrb=0; wvalid=0;
        bready=1; araddr='0; arvalid=0; rready=1; seed=32'h51a7_2026;
        repeat(3) @(posedge aclk); @(negedge aclk); aresetn=1;
        $display("STRESS: reset released");

        // Reset cancels partially received AXI-Lite transactions.
        @(negedge aclk); awaddr=32'h008; awvalid=1; araddr=32'h000; arvalid=1;
        @(posedge aclk); @(negedge aclk); aresetn=0; awvalid=0; arvalid=0;
        repeat(2) @(posedge aclk);
        if (bvalid || rvalid || awready !== 1'b1 || arready !== 1'b1)
            $fatal(1,"reset did not clear AXI state");
        @(negedge aclk); aresetn=1;
        $display("STRESS: reset cancellation passed");

        configure_identity();
        $display("STRESS: matrix configured");
        // BVALID/BRESP must remain stable while the manager is stalled.
        @(negedge aclk); bready=0; awaddr=32'h008; awvalid=1;
        wdata=0; wstrb=4'hf; wvalid=1;
        do @(posedge aclk); while (!(awready && wready));
        @(negedge aclk); awvalid=0; wvalid=0;
        do @(posedge aclk); while (!bvalid); held_bresp=bresp;
        repeat(4) begin
            @(posedge aclk);
            if (!bvalid || bresp!==held_bresp) $fatal(1,"B channel unstable");
        end
        @(negedge aclk); bready=1;
        @(posedge aclk); @(negedge aclk);

        // RVALID/RDATA/RRESP must remain stable while the manager is stalled.
        rready=0; araddr=32'h000; arvalid=1;
        do @(posedge aclk); while (!arready);
        @(negedge aclk); arvalid=0;
        do @(posedge aclk); while (!rvalid); held_rdata=rdata;
        repeat(4) begin
            @(posedge aclk);
            if (!rvalid || rdata!==held_rdata || rresp!==OKAY)
                $fatal(1,"R channel unstable");
        end
        @(negedge aclk); rready=1;
        @(posedge aclk); @(negedge aclk);
        $display("STRESS: response stalls passed");

        // Exercise alignment, strobe and decode failures.
        lite_write(32'h009,32'd0,4'hf,0,SLVERR);
        lite_write(32'h100,32'h4000_0000,4'b0011,1,SLVERR);
        lite_write(32'h044,32'd0,4'hf,0,SLVERR);
        @(negedge aclk); rready=1;
        lite_read(32'h002,SLVERR,rd);
        lite_read(32'h044,SLVERR,rd);
        lite_read(32'h018,OKAY,rd);
        if (!rd[6] || !rd[7]) $fatal(1,"decode/alignment errors missing %08x",rd);
        $display("STRESS: invalid accesses passed");

        // One complete stream vector with output backpressure and metadata checks.
        send_beat(32'h0001_0000,4'hf,0);
        send_beat(32'h0002_0000,4'hf,0);
        send_beat(32'h0003_0000,4'hf,0);
        send_beat(32'h0004_0000,4'hf,1);
        m_axis_tready=0;
        do @(posedge aclk); while (!m_axis_tvalid);
        if (m_axis_tuser[1:0] !== 0 || m_axis_tlast) $fatal(1,"first output metadata");
        held_rdata=m_axis_tdata;
        repeat(3) begin @(posedge aclk); if (!m_axis_tvalid || m_axis_tdata!==held_rdata) $fatal(1,"output changed stalled"); end
        @(negedge aclk); m_axis_tready=1;
        for (i=0;i<4;i=i+1) begin
            do @(posedge aclk); while (!(m_axis_tvalid && m_axis_tready));
            if (m_axis_tuser[1:0] !== i[1:0] || m_axis_tlast !== (i==3)) $fatal(1,"output metadata error");
        end
        lite_write(32'h008,32'h0000_0002,4'hf,0,OKAY);
        lite_read(32'h018,OKAY,rd);
        if (rd !== 0) $fatal(1,"CONTROL error clear failed");

        $display("PASS axi_precoder_stress: reset, response stalls, invalid access and stream backpressure");
        $finish;
    end
endmodule
