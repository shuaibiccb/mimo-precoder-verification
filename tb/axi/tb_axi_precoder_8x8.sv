`timescale 1ns/1ps

module tb_axi_precoder_8x8;
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
    logic [11:0] m_axis_tuser;
    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [3:0] wstrb;
    logic awvalid, awready, wvalid, wready, bvalid, bready;
    logic [1:0] bresp;
    logic arvalid, arready, rvalid, rready;
    logic [1:0] rresp;

    logic signed [15:0] input_real [0:7];
    logic signed [15:0] input_imag [0:7];
    logic [31:0] read_value;
    logic [31:0] stalled_data;
    logic [11:0] stalled_user;
    logic stalled_last;
    integer index;

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
        input logic [1:0] expected_response
    );
        begin
            @(negedge aclk);
            awaddr = address;
            awvalid = 1'b1;
            wdata = data;
            wstrb = 4'hf;
            wvalid = 1'b1;
            do @(posedge aclk); while (!(awready && wready));
            @(negedge aclk);
            awvalid = 1'b0;
            wvalid = 1'b0;
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
            araddr = address;
            arvalid = 1'b1;
            do @(posedge aclk); while (!arready);
            @(negedge aclk);
            arvalid = 1'b0;
            do @(posedge aclk); while (!rvalid);
            data = rdata;
            if (rresp !== expected_response)
                $fatal(1, "AXI read %08x response %b, expected %b",
                       address, rresp, expected_response);
            @(negedge aclk);
        end
    endtask

    task automatic configure_diagonal(
        input logic bank,
        input logic signed [15:0] diagonal
    );
        integer row, col;
        logic [31:0] address;
        logic [31:0] coefficient;
        begin
            for (row = 0; row < 8; row = row + 1) begin
                for (col = 0; col < 8; col = col + 1) begin
                    address = (bank ? 32'h0000_0200 : 32'h0000_0100)
                            + ((row * 8 + col) * 4);
                    coefficient = (row == col) ? {diagonal,16'h0000}
                                                : 32'h0000_0000;
                    axi_write(address, coefficient, OKAY);
                end
            end
        end
    endtask

    task automatic send_vector;
        integer beat;
        begin
            for (beat = 0; beat < 8; beat = beat + 1) begin
                @(negedge aclk);
                s_axis_tdata = {input_real[beat],input_imag[beat]};
                s_axis_tkeep = 4'hf;
                s_axis_tlast = (beat == 7);
                s_axis_tvalid = 1'b1;
                do @(posedge aclk); while (!s_axis_tready);
                @(negedge aclk);
                s_axis_tvalid = 1'b0;
            end
        end
    endtask

    task automatic check_output(
        input integer antenna,
        input logic negate,
        input logic [7:0] expected_version
    );
        logic signed [15:0] expected_real;
        logic signed [15:0] expected_imag;
        begin
            expected_real = negate ? -input_real[antenna] : input_real[antenna];
            expected_imag = negate ? -input_imag[antenna] : input_imag[antenna];
            do @(posedge aclk); while (!(m_axis_tvalid && m_axis_tready));
            if (($signed(m_axis_tdata[31:16]) !== expected_real)
                    || ($signed(m_axis_tdata[15:0]) !== expected_imag))
                $fatal(1, "8x8 output %0d mismatch: got %08x expected %04x_%04x",
                       antenna, m_axis_tdata, expected_real, expected_imag);
            if ((m_axis_tkeep !== 4'hf)
                    || ({m_axis_tuser[11],m_axis_tuser[1:0]} !== antenna[2:0])
                    || (m_axis_tuser[2] !== 1'b0)
                    || (m_axis_tuser[10:3] !== expected_version)
                    || (m_axis_tlast !== (antenna == 7)))
                $fatal(1, "8x8 output %0d sideband mismatch: user=%03x last=%0d",
                       antenna, m_axis_tuser, m_axis_tlast);
            @(negedge aclk);
        end
    endtask

    initial begin
        input_real[0] = 16'sd1000;  input_imag[0] = -16'sd500;
        input_real[1] = -16'sd2000; input_imag[1] = 16'sd750;
        input_real[2] = 16'sd3000;  input_imag[2] = 16'sd1250;
        input_real[3] = -16'sd4000; input_imag[3] = -16'sd1500;
        input_real[4] = 16'sd5000;  input_imag[4] = -16'sd1750;
        input_real[5] = -16'sd6000; input_imag[5] = 16'sd2000;
        input_real[6] = 16'sd7000;  input_imag[6] = 16'sd2250;
        input_real[7] = -16'sd8000; input_imag[7] = -16'sd2500;

        s_axis_tdata = '0;
        s_axis_tkeep = 4'hf;
        s_axis_tvalid = 1'b0;
        s_axis_tlast = 1'b0;
        m_axis_tready = 1'b1;
        awaddr = '0;
        awvalid = 1'b0;
        wdata = '0;
        wstrb = '0;
        wvalid = 1'b0;
        bready = 1'b1;
        araddr = '0;
        arvalid = 1'b0;
        rready = 1'b1;

        repeat (3) @(posedge aclk);
        @(negedge aclk);
        aresetn = 1'b1;

        axi_read(32'h0000_0004, OKAY, read_value);
        if (read_value !== 32'h0002_0000)
            $fatal(1, "Bad IP_VERSION in 8x8 test");
        axi_read(32'h0000_0040, OKAY, read_value);
        if (read_value !== 32'd0)
            $fatal(1, "Reset mode is not 4x4");
        axi_write(32'h0000_0040, 32'd1, OKAY);
        axi_read(32'h0000_0040, OKAY, read_value);
        if (read_value !== 32'd1)
            $fatal(1, "MODE did not switch to 8x8");

        configure_diagonal(1'b0, 16'sh4000);
        configure_diagonal(1'b1, 16'shc000);
        axi_read(32'h0000_000c, OKAY, read_value);
        if (read_value[5:4] !== 2'b11 || !read_value[1])
            $fatal(1, "8x8 banks are not complete: %08x", read_value);

        send_vector();
        m_axis_tready = 1'b0;
        do @(posedge aclk); while (!m_axis_tvalid);
        stalled_data = m_axis_tdata;
        stalled_user = m_axis_tuser;
        stalled_last = m_axis_tlast;
        repeat (3) begin
            @(posedge aclk);
            if (!m_axis_tvalid || (m_axis_tdata !== stalled_data)
                    || (m_axis_tuser !== stalled_user)
                    || (m_axis_tlast !== stalled_last))
                $fatal(1, "8x8 AXI output changed under backpressure");
        end

        axi_write(32'h0000_0040, 32'd0, SLVERR);
        axi_write(32'h0000_0010, 32'h8000_5a01, OKAY);
        if (!dut.commit_pending)
            $fatal(1, "8x8 busy commit did not become pending");

        @(negedge aclk);
        m_axis_tready = 1'b1;
        for (index = 0; index < 8; index = index + 1)
            check_output(index, 1'b0, 8'h00);

        axi_read(32'h0000_0014, OKAY, read_value);
        if (!read_value[0] || (read_value[9:2] !== 8'h5a))
            $fatal(1, "Bank1/version 5a did not activate: %08x", read_value);
        axi_read(32'h0000_0040, OKAY, read_value);
        if (read_value !== 32'd1)
            $fatal(1, "Rejected busy MODE write changed the mode");

        send_vector();
        for (index = 0; index < 8; index = index + 1)
            check_output(index, 1'b1, 8'h5a);

        axi_read(32'h0000_0024, OKAY, read_value);
        if (read_value !== 32'd2)
            $fatal(1, "8x8 input vector counter mismatch: %0d", read_value);
        axi_read(32'h0000_0028, OKAY, read_value);
        if (read_value !== 32'd2)
            $fatal(1, "8x8 output vector counter mismatch: %0d", read_value);
        axi_read(32'h0000_0038, OKAY, read_value);
        if (read_value !== 32'd128)
            $fatal(1, "8x8 matrix write counter mismatch: %0d", read_value);
        axi_read(32'h0000_0030, OKAY, read_value);
        if (read_value < 32'd3)
            $fatal(1, "8x8 output stalls were not counted");

        $display("PASS axi_precoder_8x8: mode, 64 coefficients, 8-beat vectors, metadata, hot update and backpressure");
        $finish;
    end

endmodule
