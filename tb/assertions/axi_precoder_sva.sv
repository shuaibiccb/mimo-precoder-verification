`timescale 1ns/1ps

module axi_precoder_sva (
    input logic        aclk,
    input logic        aresetn,
    input logic [31:0] s_axis_tdata,
    input logic [3:0]  s_axis_tkeep,
    input logic        s_axis_tvalid,
    input logic        s_axis_tready,
    input logic        s_axis_tlast,
    input logic [31:0] m_axis_tdata,
    input logic [3:0]  m_axis_tkeep,
    input logic        m_axis_tvalid,
    input logic        m_axis_tready,
    input logic        m_axis_tlast,
    input logic [10:0] m_axis_tuser,
    input logic [31:0] s_axil_awaddr,
    input logic        s_axil_awvalid,
    input logic        s_axil_awready,
    input logic [31:0] s_axil_wdata,
    input logic [3:0]  s_axil_wstrb,
    input logic        s_axil_wvalid,
    input logic        s_axil_wready,
    input logic [1:0]  s_axil_bresp,
    input logic        s_axil_bvalid,
    input logic        s_axil_bready,
    input logic [31:0] s_axil_araddr,
    input logic        s_axil_arvalid,
    input logic        s_axil_arready,
    input logic [31:0] s_axil_rdata,
    input logic [1:0]  s_axil_rresp,
    input logic        s_axil_rvalid,
    input logic        s_axil_rready
);

    logic [1:0] expected_output_ant;
    logic [7:0] vector_version;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            expected_output_ant <= 2'd0;
            vector_version <= 8'd0;
        end else if (m_axis_tvalid && m_axis_tready) begin
            if (expected_output_ant == 2'd0)
                vector_version <= m_axis_tuser[10:3];
            expected_output_ant <= expected_output_ant + 1'b1;
        end
    end

    property p_s_axis_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        s_axis_tvalid && !s_axis_tready |=>
            s_axis_tvalid && $stable({s_axis_tdata, s_axis_tkeep, s_axis_tlast});
    endproperty

    property p_m_axis_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid && !m_axis_tready |=>
            m_axis_tvalid && $stable({m_axis_tdata, m_axis_tkeep,
                                      m_axis_tlast, m_axis_tuser});
    endproperty

    property p_aw_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        s_axil_awvalid && !s_axil_awready |=>
            s_axil_awvalid && $stable(s_axil_awaddr);
    endproperty

    property p_w_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        s_axil_wvalid && !s_axil_wready |=>
            s_axil_wvalid && $stable({s_axil_wdata, s_axil_wstrb});
    endproperty

    property p_ar_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        s_axil_arvalid && !s_axil_arready |=>
            s_axil_arvalid && $stable(s_axil_araddr);
    endproperty

    property p_b_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        s_axil_bvalid && !s_axil_bready |=>
            s_axil_bvalid && $stable(s_axil_bresp);
    endproperty

    property p_r_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        s_axil_rvalid && !s_axil_rready |=>
            s_axil_rvalid && $stable({s_axil_rdata, s_axil_rresp});
    endproperty

    property p_output_metadata;
        @(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid |-> (m_axis_tkeep == 4'hf)
            && (m_axis_tlast == (m_axis_tuser[1:0] == 2'd3));
    endproperty

    property p_output_antenna_order;
        @(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid && m_axis_tready |->
            m_axis_tuser[1:0] == expected_output_ant;
    endproperty

    property p_version_stable_within_vector;
        @(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid && (expected_output_ant != 2'd0) |->
            m_axis_tuser[10:3] == vector_version;
    endproperty

    assert property (p_s_axis_stable_while_stalled)
        else $error("AXI-Stream input changed while stalled");
    assert property (p_m_axis_stable_while_stalled)
        else $error("AXI-Stream output changed while stalled");
    assert property (p_aw_stable_while_stalled)
        else $error("AXI-Lite AW changed while stalled");
    assert property (p_w_stable_while_stalled)
        else $error("AXI-Lite W changed while stalled");
    assert property (p_ar_stable_while_stalled)
        else $error("AXI-Lite AR changed while stalled");
    assert property (p_b_stable_while_stalled)
        else $error("AXI-Lite B changed while stalled");
    assert property (p_r_stable_while_stalled)
        else $error("AXI-Lite R changed while stalled");
    assert property (p_output_metadata)
        else $error("AXI-Stream output metadata is inconsistent");
    assert property (p_output_antenna_order)
        else $error("AXI-Stream output antenna order is incorrect");
    assert property (p_version_stable_within_vector)
        else $error("Matrix version changed within an output vector");

endmodule

bind axi_precoder_wrapper axi_precoder_sva u_axi_precoder_sva (.*);
