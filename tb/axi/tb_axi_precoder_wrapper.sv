`timescale 1ns/1ps

module tb_axi_precoder_wrapper;
    localparam logic [1:0] OKAY = 2'b00;
    localparam logic [1:0] SLVERR = 2'b10;

    logic aclk = 1'b0;
    logic aresetn = 1'b0;
    always #5 aclk = ~aclk;

    logic [31:0] s_axis_tdata;
    logic [3:0] s_axis_tkeep;
    logic s_axis_tvalid, s_axis_tready, s_axis_tlast;
    logic [31:0] m_axis_tdata;
    logic [3:0] m_axis_tkeep;
    logic m_axis_tvalid, m_axis_tready, m_axis_tlast;
    logic [10:0] m_axis_tuser;
    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [3:0] wstrb;
    logic awvalid, awready, wvalid, wready, bvalid, bready;
    logic [1:0] bresp;
    logic arvalid, arready, rvalid, rready;
    logic [1:0] rresp;

    axi_precoder_wrapper dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast), .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep), .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready), .m_axis_tlast(m_axis_tlast),
        .m_axis_tuser(m_axis_tuser), .s_axil_awaddr(awaddr),
        .s_axil_awvalid(awvalid), .s_axil_awready(awready),
        .s_axil_wdata(wdata), .s_axil_wstrb(wstrb),
        .s_axil_wvalid(wvalid), .s_axil_wready(wready),
        .s_axil_bresp(bresp), .s_axil_bvalid(bvalid),
        .s_axil_bready(bready), .s_axil_araddr(araddr),
        .s_axil_arvalid(arvalid), .s_axil_arready(arready),
        .s_axil_rdata(rdata), .s_axil_rresp(rresp),
        .s_axil_rvalid(rvalid), .s_axil_rready(rready)
    );

    task automatic axi_write(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [3:0] strobes,
        input logic w_first,
        input logic [1:0] expected_response
    );
        begin
            if (w_first) begin
                @(negedge aclk);
                wdata = data; wstrb = strobes; wvalid = 1'b1;
                do @(posedge aclk); while (!wready);
                @(negedge aclk); wvalid = 1'b0;
                @(negedge aclk);
                awaddr = address; awvalid = 1'b1;
                do @(posedge aclk); while (!awready);
                @(negedge aclk); awvalid = 1'b0;
            end else begin
                @(negedge aclk);
                awaddr = address; awvalid = 1'b1;
                do @(posedge aclk); while (!awready);
                @(negedge aclk); awvalid = 1'b0;
                @(negedge aclk);
                wdata = data; wstrb = strobes; wvalid = 1'b1;
                do @(posedge aclk); while (!wready);
                @(negedge aclk); wvalid = 1'b0;
            end
            do @(posedge aclk); while (!bvalid);
            if (bresp !== expected_response)
                $fatal(1, "AXI write %08x response %b, expected %b",
                       address, bresp, expected_response);
            @(negedge aclk);
        end
    endtask

    task automatic axi_read(
        input logic [31:0] address,
        input logic [1:0] expected_response,
        output logic [31:0] data
    );
        begin
            @(negedge aclk);
            araddr = address; arvalid = 1'b1;
            do @(posedge aclk); while (!arready);
            @(negedge aclk); arvalid = 1'b0;
            do @(posedge aclk); while (!rvalid);
            data = rdata;
            if (rresp !== expected_response)
                $fatal(1, "AXI read %08x response %b, expected %b",
                       address, rresp, expected_response);
            @(negedge aclk);
        end
    endtask

    task automatic configure_identity(input logic bank);
        integer row, col, index;
        logic [31:0] address;
        logic [31:0] coefficient;
        begin
            for (row = 0; row < 4; row = row + 1) begin
                for (col = 0; col < 4; col = col + 1) begin
                    index = row * 4 + col;
                    address = (bank ? 32'h200 : 32'h100) + index * 4;
                    coefficient = (row == col) ? 32'h4000_0000 : 32'h0;
                    axi_write(address, coefficient, 4'hf, index[0], OKAY);
                end
            end
        end
    endtask

    task automatic send_input(
        input logic signed [15:0] real_part,
        input logic signed [15:0] imag_part,
        input logic [3:0] keep,
        input logic last
    );
        begin
            @(negedge aclk);
            s_axis_tdata = {real_part, imag_part};
            s_axis_tkeep = keep;
            s_axis_tlast = last;
            s_axis_tvalid = 1'b1;
            do @(posedge aclk); while (!s_axis_tready);
            @(negedge aclk);
            s_axis_tvalid = 1'b0;
        end
    endtask

    task automatic check_output(
        input logic [1:0] antenna,
        input logic signed [15:0] expected_real,
        input logic signed [15:0] expected_imag,
        input logic [7:0] expected_version
    );
        begin
            do @(posedge aclk); while (!m_axis_tvalid);
            if ($signed(m_axis_tdata[31:16]) !== expected_real
                    || $signed(m_axis_tdata[15:0]) !== expected_imag)
                $fatal(1, "Output %0d mismatch: %08x", antenna, m_axis_tdata);
            if (m_axis_tkeep !== 4'hf
                    || m_axis_tuser[1:0] !== antenna
                    || m_axis_tuser[2] !== 1'b0
                    || m_axis_tuser[10:3] !== expected_version
                    || m_axis_tlast !== (antenna == 2'd3))
                $fatal(1, "Output %0d sideband mismatch", antenna);
            @(negedge aclk);
        end
    endtask

    logic [31:0] read_value;
    logic [31:0] stalled_data;
    logic [10:0] stalled_user;
    integer idx;

    initial begin
        s_axis_tdata = '0; s_axis_tkeep = 4'hf;
        s_axis_tvalid = 1'b0; s_axis_tlast = 1'b0;
        m_axis_tready = 1'b1;
        awaddr = '0; awvalid = 1'b0; wdata = '0; wstrb = '0; wvalid = 1'b0;
        bready = 1'b1; araddr = '0; arvalid = 1'b0; rready = 1'b1;

        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1'b1;

        axi_read(32'h000, OKAY, read_value);
        if (read_value !== 32'h4d50_5243) $fatal(1, "Bad IP_ID");
        axi_read(32'h004, OKAY, read_value);
        if (read_value !== 32'h0001_0000) $fatal(1, "Bad IP_VERSION");

        configure_identity(1'b0);
        axi_read(32'h00c, OKAY, read_value);
        if (!read_value[1] || !read_value[4]) $fatal(1, "Bank0 not complete");

        send_input(16'sd1000, -16'sd2000, 4'hf, 1'b0);
        send_input(-16'sd3000, 16'sd4000, 4'hf, 1'b0);
        send_input(16'sd5000, 16'sd6000, 4'hf, 1'b0);
        send_input(-16'sd7000, -16'sd8000, 4'hf, 1'b1);

        m_axis_tready = 1'b0;
        do @(posedge aclk); while (!m_axis_tvalid);
        stalled_data = m_axis_tdata;
        stalled_user = m_axis_tuser;
        repeat (3) begin
            @(posedge aclk);
            if (!m_axis_tvalid || m_axis_tdata !== stalled_data
                    || m_axis_tuser !== stalled_user)
                $fatal(1, "AXI output changed under backpressure");
        end
        @(negedge aclk); m_axis_tready = 1'b1;
        check_output(2'd0, 16'sd1000, -16'sd2000, 8'h00);
        check_output(2'd1, -16'sd3000, 16'sd4000, 8'h00);
        check_output(2'd2, 16'sd5000, 16'sd6000, 8'h00);
        check_output(2'd3, -16'sd7000, -16'sd8000, 8'h00);

        axi_read(32'h024, OKAY, read_value);
        if (read_value !== 32'd1) $fatal(1, "Bad input vector count");
        axi_read(32'h028, OKAY, read_value);
        if (read_value !== 32'd1) $fatal(1, "Bad output vector count");
        axi_read(32'h038, OKAY, read_value);
        if (read_value !== 32'd16) $fatal(1, "Bad configuration count");
        axi_read(32'h030, OKAY, read_value);
        if (read_value < 32'd3) $fatal(1, "Output stalls were not counted");

        send_input(16'sd1, 16'sd0, 4'hf, 1'b1);
        send_input(16'sd2, 16'sd0, 4'b0011, 1'b0);
        send_input(16'sd3, 16'sd0, 4'hf, 1'b0);
        send_input(16'sd4, 16'sd0, 4'hf, 1'b0);
        for (idx = 0; idx < 4; idx = idx + 1)
            check_output(idx[1:0], idx + 1, 16'sd0, 8'h00);
        axi_read(32'h018, OKAY, read_value);
        if (read_value[3:0] !== 4'b1111)
            $fatal(1, "Malformed stream errors were not latched: %08x", read_value);

        configure_identity(1'b1);
        axi_write(32'h010, 32'h8000_5a01, 4'hf, 1'b0, OKAY);
        axi_read(32'h014, OKAY, read_value);
        if (read_value[9:2] !== 8'h5a || !read_value[0])
            $fatal(1, "Commit did not activate Bank1/version 5a");
        axi_write(32'h010, 32'h8000_3301, 4'hf, 1'b1, SLVERR);

        axi_read(32'h100, SLVERR, read_value);
        axi_read(32'h018, OKAY, read_value);
        if (!read_value[5] || !read_value[6])
            $fatal(1, "Illegal commit/read errors were not latched");
        axi_write(32'h018, 32'h0000_00ff, 4'hf, 1'b0, OKAY);
        axi_read(32'h018, OKAY, read_value);
        if (read_value !== 32'd0) $fatal(1, "W1C did not clear errors");

        axi_write(32'h008, 32'h0000_0001, 4'hf, 1'b0, OKAY);
        axi_read(32'h024, OKAY, read_value);
        if (read_value !== 32'd0) $fatal(1, "Counter clear failed");

        $display("PASS axi_precoder_wrapper: AXI-Lite, AXI-Stream, errors and counters");
        $finish;
    end

endmodule
