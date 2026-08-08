`timescale 1ns/1ps
module tb_precoder_uvm;
    import uvm_pkg::*;
    import precoder_uvm_pkg::*;
    logic aclk=0; logic aresetn=0; always #5 aclk=~aclk;
    axi_stream_if stream_in_if(aclk,aresetn); axi_stream_if stream_out_if(aclk,aresetn); axi_lite_if lite_if(aclk,aresetn);
    performance_if perf_if(aclk,aresetn);
    axi_precoder_wrapper dut(
        .aclk(aclk),.aresetn(aresetn),
        .s_axis_tdata(stream_in_if.tdata),.s_axis_tkeep(stream_in_if.tkeep),.s_axis_tvalid(stream_in_if.tvalid),.s_axis_tready(stream_in_if.tready),.s_axis_tlast(stream_in_if.tlast),
        .m_axis_tdata(stream_out_if.tdata),.m_axis_tkeep(stream_out_if.tkeep),.m_axis_tvalid(stream_out_if.tvalid),.m_axis_tready(stream_out_if.tready),.m_axis_tlast(stream_out_if.tlast),.m_axis_tuser(stream_out_if.tuser),
        .s_axil_awaddr(lite_if.awaddr),.s_axil_awvalid(lite_if.awvalid),.s_axil_awready(lite_if.awready),.s_axil_wdata(lite_if.wdata),.s_axil_wstrb(lite_if.wstrb),.s_axil_wvalid(lite_if.wvalid),.s_axil_wready(lite_if.wready),.s_axil_bresp(lite_if.bresp),.s_axil_bvalid(lite_if.bvalid),.s_axil_bready(lite_if.bready),.s_axil_araddr(lite_if.araddr),.s_axil_arvalid(lite_if.arvalid),.s_axil_arready(lite_if.arready),.s_axil_rdata(lite_if.rdata),.s_axil_rresp(lite_if.rresp),.s_axil_rvalid(lite_if.rvalid),.s_axil_rready(lite_if.rready));

    assign perf_if.clear_counters = dut.clear_counters;
    assign perf_if.input_vector = dut.input_vector_pulse;
    assign perf_if.output_vector = dut.output_vector_pulse;
    assign perf_if.input_stall = stream_in_if.tvalid && !stream_in_if.tready;
    assign perf_if.output_stall = stream_out_if.tvalid && !stream_out_if.tready;
    assign perf_if.saturation = dut.saturation_pulse;
    assign perf_if.cfg_write = dut.cfg_write_pulse;
    assign perf_if.commit = dut.commit_pulse;
    assign perf_if.cycle_count = dut.cycle_count;
    assign perf_if.input_vector_count = dut.input_vector_count;
    assign perf_if.output_vector_count = dut.output_vector_count;
    assign perf_if.input_stall_count = dut.input_stall_count;
    assign perf_if.output_stall_count = dut.output_stall_count;
    assign perf_if.saturation_count = dut.saturation_count;
    assign perf_if.cfg_write_count = dut.cfg_write_count;
    assign perf_if.commit_count = dut.commit_count;
    assign perf_if.araddr = lite_if.araddr;
    assign perf_if.arvalid = lite_if.arvalid;
    assign perf_if.arready = lite_if.arready;
    assign perf_if.rdata = lite_if.rdata;
    assign perf_if.rresp = lite_if.rresp;
    assign perf_if.rvalid = lite_if.rvalid;
    assign perf_if.rready = lite_if.rready;
    initial begin
        uvm_config_db#(virtual axi_lite_if)::set(null,"uvm_test_top.env.lite_agent","vif",lite_if);
        uvm_config_db#(virtual axi_stream_if)::set(null,"uvm_test_top.env.stream_in_agent","vif",stream_in_if);
        uvm_config_db#(virtual axi_stream_if)::set(null,"uvm_test_top.env.stream_out_agent","vif",stream_out_if);
        uvm_config_db#(virtual performance_if)::set(null,"uvm_test_top.env.performance_monitor","vif",perf_if);
        run_test();
    end
    initial begin
        repeat(3) @(posedge aclk);
        @(negedge aclk); aresetn=1;
    end
endmodule
