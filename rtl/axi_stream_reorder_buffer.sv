`timescale 1ns/1ps

module axi_stream_reorder_buffer #(
    parameter int DATA_WIDTH = 16,
    parameter int REORDER_WAIT_CYCLES = 32
) (
    input  logic                         aclk,
    input  logic                         aresetn,
    input  logic                         enable_i,
    input  logic                         mode_8x8_i,

    input  logic                         s_valid_i,
    output logic                         s_ready_o,
    input  logic signed [DATA_WIDTH-1:0] s_real_i,
    input  logic signed [DATA_WIDTH-1:0] s_imag_i,
    input  logic                         s_last_i,
    input  logic [7:0]                   s_tid_i,

    output logic                         m_valid_o,
    input  logic                         m_ready_i,
    output logic signed [DATA_WIDTH-1:0] m_real_o,
    output logic signed [DATA_WIDTH-1:0] m_imag_o,
    output logic                         m_last_o,
    output logic [7:0]                   m_tid_o,

    output logic                         busy_o,
    output logic [1:0]                   occupancy_o,
    output logic                         reordered_pulse_o
);

    localparam int WAIT_WIDTH = (REORDER_WAIT_CYCLES <= 2)
                              ? 1 : $clog2(REORDER_WAIT_CYCLES);

    logic signed [DATA_WIDTH-1:0] slot_real [0:1][0:7];
    logic signed [DATA_WIDTH-1:0] slot_imag [0:1][0:7];
    logic [7:0] slot_tid [0:1];
    logic [2:0] slot_last_index [0:1];
    logic [1:0] slot_full;

    logic collect_active;
    logic collect_slot;
    logic [2:0] collect_index;
    logic dispatch_active;
    logic dispatch_slot;
    logic [2:0] dispatch_index;
    logic [7:0] dispatch_tid;
    logic [WAIT_WIDTH-1:0] wait_count;

    logic selected_free_slot;
    logic selected_dispatch_slot;
    logic input_handshake;
    logic output_handshake;
    logic collect_last_beat;

    always_comb begin
        selected_free_slot = slot_full[0];
        selected_dispatch_slot = 1'b0;
        if (slot_full == 2'b11)
            selected_dispatch_slot = (slot_tid[1] < slot_tid[0]);
        else if (slot_full[1])
            selected_dispatch_slot = 1'b1;
    end

    assign s_ready_o = !enable_i ? m_ready_i
                     : collect_active ? 1'b1
                     : (slot_full != 2'b11);
    assign input_handshake = s_valid_i && s_ready_o;

    assign m_valid_o = !enable_i ? s_valid_i : dispatch_active;
    assign m_real_o = !enable_i ? s_real_i
                    : slot_real[dispatch_slot][dispatch_index];
    assign m_imag_o = !enable_i ? s_imag_i
                    : slot_imag[dispatch_slot][dispatch_index];
    assign m_last_o = !enable_i ? s_last_i
                    : (dispatch_index == slot_last_index[dispatch_slot]);
    assign m_tid_o = !enable_i ? s_tid_i : dispatch_tid;
    assign output_handshake = m_valid_o && m_ready_i;

    assign collect_last_beat = collect_active
                             && (collect_index == slot_last_index[collect_slot]);
    assign occupancy_o = {1'b0,slot_full[0]} + {1'b0,slot_full[1]};
    assign busy_o = enable_i
                  && (collect_active || dispatch_active || (slot_full != 2'b00));

    integer slot_index;
    integer beat_index;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            slot_full <= 2'b00;
            collect_active <= 1'b0;
            collect_slot <= 1'b0;
            collect_index <= 3'd0;
            dispatch_active <= 1'b0;
            dispatch_slot <= 1'b0;
            dispatch_index <= 3'd0;
            dispatch_tid <= 8'd0;
            wait_count <= '0;
            reordered_pulse_o <= 1'b0;
            for (slot_index=0;slot_index<2;slot_index=slot_index+1) begin
                slot_tid[slot_index] <= 8'd0;
                slot_last_index[slot_index] <= 3'd3;
                for (beat_index=0;beat_index<8;beat_index=beat_index+1) begin
                    slot_real[slot_index][beat_index] <= '0;
                    slot_imag[slot_index][beat_index] <= '0;
                end
            end
        end else if (!enable_i) begin
            slot_full <= 2'b00;
            collect_active <= 1'b0;
            collect_index <= 3'd0;
            dispatch_active <= 1'b0;
            dispatch_index <= 3'd0;
            wait_count <= '0;
            reordered_pulse_o <= 1'b0;
        end else begin
            reordered_pulse_o <= 1'b0;

            if (input_handshake) begin
                if (!collect_active) begin
                    slot_real[selected_free_slot][0] <= s_real_i;
                    slot_imag[selected_free_slot][0] <= s_imag_i;
                    slot_tid[selected_free_slot] <= s_tid_i;
                    slot_last_index[selected_free_slot] <= mode_8x8_i ? 3'd7 : 3'd3;
                    collect_slot <= selected_free_slot;
                    collect_active <= 1'b1;
                    collect_index <= 3'd1;
                end else begin
                    slot_real[collect_slot][collect_index] <= s_real_i;
                    slot_imag[collect_slot][collect_index] <= s_imag_i;
                    if (collect_last_beat) begin
                        slot_full[collect_slot] <= 1'b1;
                        collect_active <= 1'b0;
                        collect_index <= 3'd0;
                    end else begin
                        collect_index <= collect_index + 1'b1;
                    end
                end
            end

            if (!dispatch_active) begin
                if (slot_full == 2'b11) begin
                    dispatch_active <= 1'b1;
                    dispatch_slot <= selected_dispatch_slot;
                    dispatch_index <= 3'd0;
                    dispatch_tid <= slot_tid[selected_dispatch_slot];
                    wait_count <= '0;
                    if (selected_dispatch_slot == 1'b1)
                        reordered_pulse_o <= 1'b1;
                end else if (slot_full != 2'b00) begin
                    if (wait_count == REORDER_WAIT_CYCLES-1) begin
                        dispatch_active <= 1'b1;
                        dispatch_slot <= selected_dispatch_slot;
                        dispatch_index <= 3'd0;
                        dispatch_tid <= slot_tid[selected_dispatch_slot];
                        wait_count <= '0;
                    end else begin
                        wait_count <= wait_count + 1'b1;
                    end
                end else begin
                    wait_count <= '0;
                end
            end else if (output_handshake) begin
                if (dispatch_index == slot_last_index[dispatch_slot]) begin
                    slot_full[dispatch_slot] <= 1'b0;
                    dispatch_active <= 1'b0;
                    dispatch_index <= 3'd0;
                end else begin
                    dispatch_index <= dispatch_index + 1'b1;
                end
            end
        end
    end

endmodule
