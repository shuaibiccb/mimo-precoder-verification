`timescale 1ns/1ps

module axi_lite_regs (
    input  logic        aclk,
    input  logic        aresetn,

    input  logic [31:0] s_axil_awaddr,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,
    input  logic [31:0] s_axil_wdata,
    input  logic [3:0]  s_axil_wstrb,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,
    output logic [1:0]  s_axil_bresp,
    output logic        s_axil_bvalid,
    input  logic        s_axil_bready,

    input  logic [31:0] s_axil_araddr,
    input  logic        s_axil_arvalid,
    output logic        s_axil_arready,
    output logic [31:0] s_axil_rdata,
    output logic [1:0]  s_axil_rresp,
    output logic        s_axil_rvalid,
    input  logic        s_axil_rready,

    output logic        cfg_valid_o,
    input  logic        cfg_ready_i,
    output logic        cfg_bank_o,
    output logic [2:0]  cfg_row_o,
    output logic [2:0]  cfg_col_o,
    output logic signed [15:0] cfg_real_o,
    output logic signed [15:0] cfg_imag_o,

    output logic        mode_8x8_o,
    output logic        format_12_o,
    output logic        format_change_o,
    output logic        truncate_o,
    output logic        wrap_o,
    output logic        reorder_enable_o,

    output logic        commit_valid_o,
    input  logic        commit_ready_i,
    output logic        commit_bank_o,
    output logic [7:0]  commit_version_o,

    input  logic        busy_i,
    input  logic        reorder_busy_i,
    input  logic [1:0]  reorder_occupancy_i,
    input  logic        matrix_complete_i,
    input  logic [1:0]  bank_complete_i,
    input  logic        commit_pending_i,
    input  logic        active_bank_i,
    input  logic [7:0]  active_version_i,
    input  logic        core_protocol_error_i,
    input  logic        input_early_tlast_i,
    input  logic        input_missing_tlast_i,
    input  logic        input_invalid_tkeep_i,

    input  logic [31:0] cycle_count_i,
    input  logic [31:0] input_vector_count_i,
    input  logic [31:0] output_vector_count_i,
    input  logic [31:0] input_stall_count_i,
    input  logic [31:0] output_stall_count_i,
    input  logic [31:0] saturation_count_i,
    input  logic [31:0] cfg_write_count_i,
    input  logic [31:0] commit_count_i,

    output logic        clear_counters_o,
    output logic        cfg_write_pulse_o,
    output logic        commit_pulse_o,
    output logic [7:0]  error_status_o
);

    localparam logic [1:0] AXI_OKAY   = 2'b00;
    localparam logic [1:0] AXI_SLVERR = 2'b10;

    logic        aw_stored;
    logic [31:0] awaddr_stored;
    logic        w_stored;
    logic [31:0] wdata_stored;
    logic [3:0]  wstrb_stored;
    logic        write_execute;
    logic [31:0] write_data_masked;
    logic [1:0]  write_response;
    logic        write_decode_error;
    logic        write_align_error;
    logic        illegal_matrix_write;
    logic        illegal_commit;
    logic        mode_write;
    logic        mode_write_value;
    logic        format_write;
    logic        format_write_value;
    logic        quant_write;
    logic        quant_write_truncate;
    logic        quant_write_wrap;
    logic        reorder_write;
    logic        reorder_write_value;
    logic        clear_errors;
    logic [7:0]  error_w1c_mask;

    logic [31:0] read_data_next;
    logic [1:0]  read_response_next;
    logic        read_decode_error;
    logic        read_align_error;
    logic [7:0]  error_set;
    logic        core_protocol_error_q;

    integer byte_index;
    always_comb begin
        write_data_masked = 32'd0;
        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
            if (wstrb_stored[byte_index])
                write_data_masked[byte_index*8 +: 8] =
                    wdata_stored[byte_index*8 +: 8];
        end
    end

    assign s_axil_awready = !aw_stored && !s_axil_bvalid;
    assign s_axil_wready = !w_stored && !s_axil_bvalid;
    assign write_execute = aw_stored && w_stored && !s_axil_bvalid;
    assign s_axil_arready = !s_axil_rvalid;

    always_comb begin
        cfg_valid_o = 1'b0;
        cfg_bank_o = (awaddr_stored >= 32'h0000_0200);
        cfg_row_o = mode_8x8_o ? awaddr_stored[7:5]
                               : {1'b0,awaddr_stored[5:4]};
        cfg_col_o = mode_8x8_o ? awaddr_stored[4:2]
                               : {1'b0,awaddr_stored[3:2]};
        cfg_real_o = wdata_stored[31:16];
        cfg_imag_o = wdata_stored[15:0];

        commit_valid_o = 1'b0;
        commit_bank_o = write_data_masked[0];
        commit_version_o = write_data_masked[15:8];

        clear_counters_o = 1'b0;
        clear_errors = 1'b0;
        error_w1c_mask = 8'd0;
        cfg_write_pulse_o = 1'b0;
        commit_pulse_o = 1'b0;
        write_response = AXI_OKAY;
        write_decode_error = 1'b0;
        write_align_error = 1'b0;
        illegal_matrix_write = 1'b0;
        illegal_commit = 1'b0;
        mode_write = 1'b0;
        mode_write_value = mode_8x8_o;
        format_write = 1'b0;
        format_write_value = format_12_o;
        format_change_o = 1'b0;
        quant_write = 1'b0;
        quant_write_truncate = truncate_o;
        quant_write_wrap = wrap_o;
        reorder_write = 1'b0;
        reorder_write_value = reorder_enable_o;

        if (write_execute) begin
            if (awaddr_stored[1:0] != 2'b00) begin
                write_response = AXI_SLVERR;
                write_align_error = 1'b1;
            end else if (((awaddr_stored >= 32'h0000_0100)
                          && (awaddr_stored <= (mode_8x8_o
                                               ? 32'h0000_01fc
                                               : 32'h0000_013c)))
                         || ((awaddr_stored >= 32'h0000_0200)
                             && (awaddr_stored <= (mode_8x8_o
                                                  ? 32'h0000_02fc
                                                  : 32'h0000_023c)))) begin
                if ((wstrb_stored != 4'b1111) || !cfg_ready_i
                        || reorder_busy_i
                        || (format_12_o
                            && ((write_data_masked[31:28] != {4{write_data_masked[27]}})
                             || (write_data_masked[15:12] != {4{write_data_masked[11]}})))) begin
                    write_response = AXI_SLVERR;
                    illegal_matrix_write = 1'b1;
                    if (wstrb_stored != 4'b1111)
                        write_align_error = 1'b1;
                end else begin
                    cfg_valid_o = 1'b1;
                    cfg_write_pulse_o = 1'b1;
                end
            end else begin
                case (awaddr_stored)
                    32'h0000_0008: begin
                        clear_counters_o = write_data_masked[0];
                        clear_errors = write_data_masked[1];
                    end
                    32'h0000_0010: begin
                        if (write_data_masked[31]) begin
                            if ((write_data_masked[30:16] != 15'd0)
                                    || (write_data_masked[7:1] != 7'd0)
                                    || !commit_ready_i || reorder_busy_i) begin
                                write_response = AXI_SLVERR;
                                illegal_commit = 1'b1;
                            end else begin
                                commit_valid_o = 1'b1;
                                commit_pulse_o = 1'b1;
                            end
                        end
                    end
                    32'h0000_0018: error_w1c_mask = write_data_masked[7:0];
                    32'h0000_0040: begin
                        if ((wstrb_stored != 4'b1111)
                                || (write_data_masked[31:1] != 31'd0)
                                || busy_i || commit_pending_i) begin
                            write_response = AXI_SLVERR;
                            illegal_matrix_write = 1'b1;
                            if (wstrb_stored != 4'b1111)
                                write_align_error = 1'b1;
                        end else begin
                            mode_write = 1'b1;
                            mode_write_value = write_data_masked[0];
                        end
                    end
                    32'h0000_0044: begin
                        if ((wstrb_stored != 4'b1111)
                                || (write_data_masked[31:1] != 31'd0)
                                || busy_i || commit_pending_i) begin
                            write_response = AXI_SLVERR;
                            illegal_matrix_write = 1'b1;
                            if (wstrb_stored != 4'b1111)
                                write_align_error = 1'b1;
                        end else begin
                            format_write = 1'b1;
                            format_write_value = write_data_masked[0];
                            format_change_o = 1'b1;
                        end
                    end
                    32'h0000_0048: begin
                        if ((wstrb_stored != 4'b1111)
                                || (write_data_masked[31:2] != 30'd0)
                                || busy_i || commit_pending_i) begin
                            write_response = AXI_SLVERR;
                            illegal_matrix_write = 1'b1;
                            if (wstrb_stored != 4'b1111)
                                write_align_error = 1'b1;
                        end else begin
                            quant_write = 1'b1;
                            quant_write_truncate = write_data_masked[0];
                            quant_write_wrap = write_data_masked[1];
                        end
                    end
                    32'h0000_004c: begin
                        if ((wstrb_stored != 4'b1111)
                                || (write_data_masked[31:1] != 31'd0)
                                || busy_i || commit_pending_i) begin
                            write_response = AXI_SLVERR;
                            illegal_matrix_write = 1'b1;
                            if (wstrb_stored != 4'b1111)
                                write_align_error = 1'b1;
                        end else begin
                            reorder_write = 1'b1;
                            reorder_write_value = write_data_masked[0];
                        end
                    end
                    default: begin
                        write_response = AXI_SLVERR;
                        write_decode_error = 1'b1;
                    end
                endcase
            end
        end
    end

    always_comb begin
        read_data_next = 32'd0;
        read_response_next = AXI_OKAY;
        read_decode_error = 1'b0;
        read_align_error = 1'b0;

        if (s_axil_araddr[1:0] != 2'b00) begin
            read_response_next = AXI_SLVERR;
            read_align_error = 1'b1;
        end else begin
            case (s_axil_araddr)
                32'h0000_0000: read_data_next = 32'h4d50_5243;
                32'h0000_0004: read_data_next = 32'h0002_0000;
                32'h0000_000c: read_data_next = {
                    26'd0, bank_complete_i[1], bank_complete_i[0],
                    active_bank_i, commit_pending_i, matrix_complete_i, busy_i
                };
                32'h0000_0014: read_data_next = {
                    22'd0, active_version_i, commit_pending_i, active_bank_i
                };
                32'h0000_0018: read_data_next = {24'd0, error_status_o};
                32'h0000_0020: read_data_next = cycle_count_i;
                32'h0000_0024: read_data_next = input_vector_count_i;
                32'h0000_0028: read_data_next = output_vector_count_i;
                32'h0000_002c: read_data_next = input_stall_count_i;
                32'h0000_0030: read_data_next = output_stall_count_i;
                32'h0000_0034: read_data_next = saturation_count_i;
                32'h0000_0038: read_data_next = cfg_write_count_i;
                32'h0000_003c: read_data_next = commit_count_i;
                32'h0000_0040: read_data_next = {31'd0,mode_8x8_o};
                32'h0000_0044: read_data_next = {31'd0,format_12_o};
                32'h0000_0048: read_data_next = {30'd0,wrap_o,truncate_o};
                32'h0000_004c: read_data_next = {
                    28'd0, reorder_occupancy_i, reorder_busy_i,
                    reorder_enable_o
                };
                default: begin
                    read_response_next = AXI_SLVERR;
                    read_decode_error = 1'b1;
                end
            endcase
        end
    end

    always_comb begin
        error_set = 8'd0;
        error_set[0] = core_protocol_error_i && !core_protocol_error_q;
        error_set[1] = input_early_tlast_i;
        error_set[2] = input_missing_tlast_i;
        error_set[3] = input_invalid_tkeep_i;
        error_set[4] = illegal_matrix_write;
        error_set[5] = illegal_commit;
        error_set[6] = write_decode_error
                     || (s_axil_arvalid && s_axil_arready && read_decode_error);
        error_set[7] = write_align_error
                     || (s_axil_arvalid && s_axil_arready && read_align_error);
    end

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            aw_stored <= 1'b0;
            awaddr_stored <= 32'd0;
            w_stored <= 1'b0;
            wdata_stored <= 32'd0;
            wstrb_stored <= 4'd0;
            s_axil_bvalid <= 1'b0;
            s_axil_bresp <= AXI_OKAY;
            s_axil_rvalid <= 1'b0;
            s_axil_rdata <= 32'd0;
            s_axil_rresp <= AXI_OKAY;
            error_status_o <= 8'd0;
            core_protocol_error_q <= 1'b0;
            mode_8x8_o <= 1'b0;
            format_12_o <= 1'b0;
            truncate_o <= 1'b0;
            wrap_o <= 1'b0;
            reorder_enable_o <= 1'b0;
        end else begin
            core_protocol_error_q <= core_protocol_error_i;
            if (mode_write)
                mode_8x8_o <= mode_write_value;
            if (format_write)
                format_12_o <= format_write_value;
            if (quant_write) begin
                truncate_o <= quant_write_truncate;
                wrap_o <= quant_write_wrap;
            end
            if (reorder_write)
                reorder_enable_o <= reorder_write_value;
            if (s_axil_awvalid && s_axil_awready) begin
                aw_stored <= 1'b1;
                awaddr_stored <= s_axil_awaddr;
            end
            if (s_axil_wvalid && s_axil_wready) begin
                w_stored <= 1'b1;
                wdata_stored <= s_axil_wdata;
                wstrb_stored <= s_axil_wstrb;
            end

            if (write_execute) begin
                aw_stored <= 1'b0;
                w_stored <= 1'b0;
                s_axil_bvalid <= 1'b1;
                s_axil_bresp <= write_response;
            end else if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end

            if (s_axil_arvalid && s_axil_arready) begin
                s_axil_rvalid <= 1'b1;
                s_axil_rdata <= read_data_next;
                s_axil_rresp <= read_response_next;
            end else if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid <= 1'b0;
            end

            if (clear_errors)
                error_status_o <= error_set;
            else
                error_status_o <= (error_status_o & ~error_w1c_mask) | error_set;
        end
    end

endmodule
