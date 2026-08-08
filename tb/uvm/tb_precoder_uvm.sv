`timescale 1ns/1ps
module tb_precoder_uvm;
    import uvm_pkg::*;
    import precoder_uvm_pkg::*;
    logic aclk=0; logic aresetn=0; always #5 aclk=~aclk;
    axi_stream_if stream_in_if(aclk,aresetn); axi_stream_if stream_out_if(aclk,aresetn); axi_lite_if lite_if(aclk,aresetn);
    axi_precoder_wrapper dut(
        .aclk(aclk),.aresetn(aresetn),
        .s_axis_tdata(stream_in_if.tdata),.s_axis_tkeep(stream_in_if.tkeep),.s_axis_tvalid(stream_in_if.tvalid),.s_axis_tready(stream_in_if.tready),.s_axis_tlast(stream_in_if.tlast),
        .m_axis_tdata(stream_out_if.tdata),.m_axis_tkeep(stream_out_if.tkeep),.m_axis_tvalid(stream_out_if.tvalid),.m_axis_tready(stream_out_if.tready),.m_axis_tlast(stream_out_if.tlast),.m_axis_tuser(stream_out_if.tuser),
        .s_axil_awaddr(lite_if.awaddr),.s_axil_awvalid(lite_if.awvalid),.s_axil_awready(lite_if.awready),.s_axil_wdata(lite_if.wdata),.s_axil_wstrb(lite_if.wstrb),.s_axil_wvalid(lite_if.wvalid),.s_axil_wready(lite_if.wready),.s_axil_bresp(lite_if.bresp),.s_axil_bvalid(lite_if.bvalid),.s_axil_bready(lite_if.bready),.s_axil_araddr(lite_if.araddr),.s_axil_arvalid(lite_if.arvalid),.s_axil_arready(lite_if.arready),.s_axil_rdata(lite_if.rdata),.s_axil_rresp(lite_if.rresp),.s_axil_rvalid(lite_if.rvalid),.s_axil_rready(lite_if.rready));
    initial begin
        uvm_config_db#(virtual axi_lite_if)::set(null,"uvm_test_top.env.lite_agent","vif",lite_if);
        uvm_config_db#(virtual axi_stream_if)::set(null,"uvm_test_top.env.stream_in_agent","vif",stream_in_if);
        uvm_config_db#(virtual axi_stream_if)::set(null,"uvm_test_top.env.stream_out_agent","vif",stream_out_if);
        run_test();
    end
    initial begin
        repeat(3) @(posedge aclk);
        @(negedge aclk); aresetn=1;
    end
endmodule
