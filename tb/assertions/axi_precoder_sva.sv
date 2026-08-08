`timescale 1ns/1ps

module axi_precoder_sva (
    input logic        aclk,
    input logic        aresetn,
    input logic        mode_8x8,
    input logic [31:0] s_axis_tdata,
    input logic [3:0]  s_axis_tkeep,
    input logic [7:0]  s_axis_tid,
    input logic        s_axis_tvalid,
    input logic        s_axis_tready,
    input logic        s_axis_tlast,
    input logic [31:0] m_axis_tdata,
    input logic [3:0]  m_axis_tkeep,
    input logic        m_axis_tvalid,
    input logic        m_axis_tready,
    input logic        m_axis_tlast,
    input logic [11:0] m_axis_tuser,
    input logic [7:0]  m_axis_tid,
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

    logic [2:0] expected_output_ant;
    logic [2:0] input_vector_beat;
    logic [7:0] input_tid;
    logic [7:0] accepted_tid;
    logic [7:0] vector_version;
    logic [7:0] vector_tid;
    logic aw_pending;
    logic w_pending;
    logic write_outstanding;
    logic read_outstanding;
    integer input_beat_count;
    integer output_beat_count;
    integer write_response_count;
    integer read_response_count;
    logic strict_input_protocol;

    initial strict_input_protocol = $test$plusargs("STRICT_AXI_INPUT");

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            expected_output_ant <= 3'd0;
            input_vector_beat <= 3'd0;
            input_tid <= 8'd0;
            accepted_tid <= 8'd0;
            vector_version <= 8'd0;
            vector_tid <= 8'd0;
            aw_pending <= 1'b0;
            w_pending <= 1'b0;
            write_outstanding <= 1'b0;
            read_outstanding <= 1'b0;
            input_beat_count <= 0;
            output_beat_count <= 0;
            write_response_count <= 0;
            read_response_count <= 0;
        end else if (m_axis_tvalid && m_axis_tready) begin
            if (expected_output_ant == 2'd0) begin
                vector_version <= m_axis_tuser[10:3];
                vector_tid <= m_axis_tid;
            end
            if (m_axis_tlast)
                expected_output_ant <= 3'd0;
            else
                expected_output_ant <= expected_output_ant + 1'b1;
            output_beat_count <= output_beat_count + 1;
        end
        if (aresetn) begin
            if (s_axis_tvalid && s_axis_tready) begin
                input_beat_count <= input_beat_count + 1;
                if (input_vector_beat == 3'd0) begin
                    input_tid <= s_axis_tid;
                    accepted_tid <= s_axis_tid;
                end
                if (s_axis_tlast)
                    input_vector_beat <= 3'd0;
                else
                    input_vector_beat <= input_vector_beat + 1'b1;
            end
            if (s_axil_awvalid && s_axil_awready)
                aw_pending <= 1'b1;
            if (s_axil_wvalid && s_axil_wready)
                w_pending <= 1'b1;
            if ((aw_pending || (s_axil_awvalid && s_axil_awready))
                    && (w_pending || (s_axil_wvalid && s_axil_wready))) begin
                write_outstanding <= 1'b1;
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
            end
            if (s_axil_bvalid && s_axil_bready) begin
                write_outstanding <= 1'b0;
                write_response_count <= write_response_count + 1;
            end
            if (s_axil_arvalid && s_axil_arready)
                read_outstanding <= 1'b1;
            if (s_axil_rvalid && s_axil_rready) begin
                read_outstanding <= 1'b0;
                read_response_count <= read_response_count + 1;
            end
        end
    end

    property p_s_axis_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        s_axis_tvalid && !s_axis_tready |=>
            s_axis_tvalid && $stable({s_axis_tdata, s_axis_tkeep, s_axis_tlast, s_axis_tid});
    endproperty

    property p_m_axis_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid && !m_axis_tready |=>
            m_axis_tvalid && $stable({m_axis_tdata, m_axis_tkeep,
                                      m_axis_tlast, m_axis_tuser, m_axis_tid});
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
            && (m_axis_tlast
                == ({m_axis_tuser[11],m_axis_tuser[1:0]}
                    == (mode_8x8 ? 3'd7 : 3'd3)));
    endproperty

    property p_output_antenna_order;
        @(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid && m_axis_tready |->
            {m_axis_tuser[11],m_axis_tuser[1:0]} == expected_output_ant;
    endproperty

    property p_version_stable_within_vector;
        @(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid && (expected_output_ant != 3'd0) |->
            m_axis_tuser[10:3] == vector_version;
    endproperty

    property p_tid_stable_within_vector;
        @(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid && (expected_output_ant != 3'd0) |->
            m_axis_tid == vector_tid;
    endproperty

    property p_b_has_complete_request;
        @(posedge aclk) disable iff (!aresetn)
        s_axil_bvalid |-> write_outstanding;
    endproperty

    property p_r_has_read_request;
        @(posedge aclk) disable iff (!aresetn)
        s_axil_rvalid |-> read_outstanding;
    endproperty

    property p_bresp_is_legal;
        @(posedge aclk) disable iff (!aresetn)
        s_axil_bvalid |-> s_axil_bresp inside {2'b00, 2'b10};
    endproperty

    property p_rresp_is_legal;
        @(posedge aclk) disable iff (!aresetn)
        s_axil_rvalid |-> s_axil_rresp inside {2'b00, 2'b10};
    endproperty

    property p_input_packet_shape;
        @(posedge aclk) disable iff (!aresetn)
        strict_input_protocol && s_axis_tvalid && s_axis_tready |->
            (s_axis_tkeep == 4'hf)
            && (s_axis_tlast
                == (input_vector_beat == (mode_8x8 ? 3'd7 : 3'd3)));
    endproperty

    property p_input_tid_stable_within_vector;
        @(posedge aclk) disable iff (!aresetn)
        s_axis_tvalid && s_axis_tready && (input_vector_beat != 3'd0) |->
            s_axis_tid == input_tid;
    endproperty

    property p_output_tid_matches_input;
        @(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid |-> m_axis_tid == accepted_tid;
    endproperty

    assert property (p_s_axis_stable_while_stalled)
        else $error("AXI-Stream input changed while stalled");
    assert property (p_m_axis_stable_while_stalled)
        else $error("AXI-Stream output changed while stalled");
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
    assert property (p_tid_stable_within_vector)
        else $error("AXI-Stream transaction ID changed within an output vector");
    assert property (p_b_has_complete_request)
        else $error("AXI-Lite B response has no complete AW/W request");
    assert property (p_r_has_read_request)
        else $error("AXI-Lite R response has no accepted AR request");
    assert property (p_bresp_is_legal)
        else $error("AXI-Lite B response code is illegal");
    assert property (p_rresp_is_legal)
        else $error("AXI-Lite R response code is illegal");
    assert property (p_input_packet_shape)
        else $error("AXI-Stream input packet length does not match MODE");
    assert property (p_input_tid_stable_within_vector)
        else $error("AXI-Stream input transaction ID changed within a vector");
    assert property (p_output_tid_matches_input)
        else $error("AXI-Stream output transaction ID does not match input");

    cover property (@(posedge aclk) disable iff (!aresetn)
        s_axil_awvalid && s_axil_awready ##[1:8]
        s_axil_wvalid && s_axil_wready);
    cover property (@(posedge aclk) disable iff (!aresetn)
        s_axil_wvalid && s_axil_wready ##[1:8]
        s_axil_awvalid && s_axil_awready);
    cover property (@(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid && !m_axis_tready ##1
        m_axis_tvalid && $stable({m_axis_tdata, m_axis_tuser}));
    cover property (@(posedge aclk) disable iff (!aresetn)
        s_axil_bvalid && !s_axil_bready ##1 s_axil_bvalid);
    cover property (@(posedge aclk) disable iff (!aresetn)
        s_axil_rvalid && !s_axil_rready ##1 s_axil_rvalid);
    cover property (@(posedge aclk) disable iff (!aresetn)
        m_axis_tvalid && m_axis_tready && m_axis_tuser[2]);

    final begin
        $display("[PHASE9_SVA_AXI] input_beats=%0d output_beats=%0d writes=%0d reads=%0d",
                 input_beat_count, output_beat_count,
                 write_response_count, read_response_count);
    end

endmodule

bind axi_precoder_wrapper axi_precoder_sva u_axi_precoder_sva (.*);
