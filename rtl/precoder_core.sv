`timescale 1ns/1ps

module precoder_core #(
    parameter int DATA_WIDTH    = 16,
    parameter int ACC_WIDTH     = 40,
    parameter int VERSION_WIDTH = 8
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic                         mode_8x8_i,
    input  logic                         format_12_i,
    input  logic                         format_change_i,
    input  logic                         truncate_i,
    input  logic                         wrap_i,

    input  logic                         cfg_valid_i,
    output logic                         cfg_ready_o,
    input  logic                         cfg_bank_i,
    input  logic [2:0]                   cfg_row_i,
    input  logic [2:0]                   cfg_col_i,
    input  logic signed [DATA_WIDTH-1:0] cfg_real_i,
    input  logic signed [DATA_WIDTH-1:0] cfg_imag_i,
    output logic [1:0]                   bank_complete_o,
    output logic                         matrix_complete_o,

    input  logic                         commit_valid_i,
    output logic                         commit_ready_o,
    input  logic                         commit_bank_i,
    input  logic [VERSION_WIDTH-1:0]     commit_version_i,
    output logic                         commit_pending_o,
    output logic                         active_bank_o,
    output logic [VERSION_WIDTH-1:0]     active_version_o,

    input  logic                         in_valid_i,
    output logic                         in_ready_o,
    input  logic signed [DATA_WIDTH-1:0] in_real_i,
    input  logic signed [DATA_WIDTH-1:0] in_imag_i,
    input  logic                         in_last_i,

    output logic                         out_valid_o,
    input  logic                         out_ready_i,
    output logic signed [DATA_WIDTH-1:0] out_real_o,
    output logic signed [DATA_WIDTH-1:0] out_imag_o,
    output logic [2:0]                   out_ant_idx_o,
    output logic                         out_last_o,
    output logic                         out_saturated_o,
    output logic [VERSION_WIDTH-1:0]     out_version_o,

    output logic                         busy_o,
    output logic                         protocol_error_o
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_LOAD,
        ST_COMPUTE,
        ST_CAPTURE,
        ST_OUTPUT
    } state_t;

    state_t state;
    logic [2:0] symbol_write_idx;
    logic [2:0] compute_idx;
    logic [2:0] output_idx;
    logic       row_group;
    logic       cfg_write;
    logic       symbol_write;
    logic       input_handshake;
    logic       output_handshake;
    logic       commit_handshake;
    logic       mac_clear;
    logic       mac_enable;
    logic       vector_start;
    logic       group_clear;
    logic       pending_bank;
    logic [VERSION_WIDTH-1:0] pending_version;
    logic       transaction_bank;
    logic       transaction_mode_8x8;
    logic       transaction_format_12;
    logic       transaction_truncate;
    logic       transaction_wrap;
    logic [VERSION_WIDTH-1:0] transaction_version;
    logic [VERSION_WIDTH-1:0] result_version;
    logic [2:0] transaction_last_index;

    logic signed [DATA_WIDTH-1:0] symbol_real;
    logic signed [DATA_WIDTH-1:0] symbol_imag;
    logic signed [DATA_WIDTH-1:0] coeff_real [0:3];
    logic signed [DATA_WIDTH-1:0] coeff_imag [0:3];
    logic signed [ACC_WIDTH-1:0]  acc_real [0:3];
    logic signed [ACC_WIDTH-1:0]  acc_imag [0:3];
    logic signed [DATA_WIDTH-1:0] rounded_real [0:3];
    logic signed [DATA_WIDTH-1:0] rounded_imag [0:3];
    logic                         sat_real [0:3];
    logic                         sat_imag [0:3];
    logic signed [11:0]            rounded_real_12 [0:3];
    logic signed [11:0]            rounded_imag_12 [0:3];
    logic                         sat_real_12 [0:3];
    logic                         sat_imag_12 [0:3];
    logic signed [DATA_WIDTH-1:0] result_real [0:7];
    logic signed [DATA_WIDTH-1:0] result_imag [0:7];
    logic                         result_sat [0:7];

    assign cfg_ready_o = ((state == ST_IDLE) || (cfg_bank_i != active_bank_o))
                       && (!commit_pending_o || (cfg_bank_i != pending_bank));
    assign cfg_write = cfg_valid_i && cfg_ready_o;

    assign commit_ready_o = !commit_pending_o
                          && bank_complete_o[commit_bank_i]
                          && (commit_bank_i != active_bank_o);
    assign commit_handshake = commit_valid_i && commit_ready_o;

    assign matrix_complete_o = bank_complete_o[active_bank_o];
    assign in_ready_o = matrix_complete_o
                      && !format_change_i
                      && ((state == ST_LOAD)
                          || ((state == ST_IDLE) && !cfg_valid_i && !commit_valid_i));
    assign input_handshake = in_valid_i && in_ready_o;
    assign symbol_write = input_handshake;
    assign out_valid_o = (state == ST_OUTPUT);
    assign output_handshake = out_valid_o && out_ready_i;
    assign out_ant_idx_o = output_idx;
    assign transaction_last_index = transaction_mode_8x8 ? 3'd7 : 3'd3;
    assign out_last_o = out_valid_o && (output_idx == transaction_last_index);
    assign out_version_o = result_version;
    assign busy_o = (state != ST_IDLE);
    assign vector_start = input_handshake && (state == ST_IDLE);
    assign group_clear = (state == ST_CAPTURE) && transaction_mode_8x8 && !row_group;
    assign mac_clear = vector_start || group_clear;
    assign mac_enable = (state == ST_COMPUTE);

    matrix_storage #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_matrix_storage (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mode_8x8_i(mode_8x8_i),
        .format_change_i(format_change_i),
        .write_en_i(cfg_write),
        .write_bank_i(cfg_bank_i),
        .write_row_i(cfg_row_i),
        .write_col_i(cfg_col_i),
        .write_real_i(cfg_real_i),
        .write_imag_i(cfg_imag_i),
        .read_bank_i(transaction_bank),
        .read_row_group_i(row_group),
        .read_col_i(compute_idx),
        .row0_real_o(coeff_real[0]),
        .row0_imag_o(coeff_imag[0]),
        .row1_real_o(coeff_real[1]),
        .row1_imag_o(coeff_imag[1]),
        .row2_real_o(coeff_real[2]),
        .row2_imag_o(coeff_imag[2]),
        .row3_real_o(coeff_real[3]),
        .row3_imag_o(coeff_imag[3]),
        .complete_o(bank_complete_o)
    );

    symbol_buffer #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_symbol_buffer (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .write_en_i(symbol_write),
        .write_idx_i(symbol_write_idx),
        .write_real_i(in_real_i),
        .write_imag_i(in_imag_i),
        .read_idx_i(compute_idx),
        .read_real_o(symbol_real),
        .read_imag_o(symbol_imag)
    );

    genvar lane;
    generate
        for (lane = 0; lane < 4; lane = lane + 1) begin : g_lane
            complex_mac #(
                .IN_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
            ) u_mac (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .clear_i(mac_clear),
                .enable_i(mac_enable),
                .a_real_i(coeff_real[lane]),
                .a_imag_i(coeff_imag[lane]),
                .b_real_i(symbol_real),
                .b_imag_i(symbol_imag),
                .acc_real_o(acc_real[lane]),
                .acc_imag_o(acc_imag[lane])
            );

            fixed_round_sat #(
                .ACC_WIDTH(ACC_WIDTH),
                .IN_FRAC(28),
                .OUT_WIDTH(DATA_WIDTH),
                .OUT_FRAC(14)
            ) u_round_real (
                .acc_i(acc_real[lane]),
                .truncate_i(transaction_truncate),
                .wrap_i(transaction_wrap),
                .data_o(rounded_real[lane]),
                .saturated_o(sat_real[lane])
            );

            fixed_round_sat #(
                .ACC_WIDTH(ACC_WIDTH),
                .IN_FRAC(28),
                .OUT_WIDTH(DATA_WIDTH),
                .OUT_FRAC(14)
            ) u_round_imag (
                .acc_i(acc_imag[lane]),
                .truncate_i(transaction_truncate),
                .wrap_i(transaction_wrap),
                .data_o(rounded_imag[lane]),
                .saturated_o(sat_imag[lane])
            );

            fixed_round_sat #(
                .ACC_WIDTH(ACC_WIDTH),
                .IN_FRAC(20),
                .OUT_WIDTH(12),
                .OUT_FRAC(10)
            ) u_round_real_12 (
                .acc_i(acc_real[lane]),
                .truncate_i(transaction_truncate),
                .wrap_i(transaction_wrap),
                .data_o(rounded_real_12[lane]),
                .saturated_o(sat_real_12[lane])
            );

            fixed_round_sat #(
                .ACC_WIDTH(ACC_WIDTH),
                .IN_FRAC(20),
                .OUT_WIDTH(12),
                .OUT_FRAC(10)
            ) u_round_imag_12 (
                .acc_i(acc_imag[lane]),
                .truncate_i(transaction_truncate),
                .wrap_i(transaction_wrap),
                .data_o(rounded_imag_12[lane]),
                .saturated_o(sat_imag_12[lane])
            );
        end
    endgenerate

    always_comb begin
        out_real_o = result_real[output_idx];
        out_imag_o = result_imag[output_idx];
        out_saturated_o = result_sat[output_idx];
    end

    integer result_idx;
    integer capture_idx;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state <= ST_IDLE;
            symbol_write_idx <= '0;
            compute_idx <= '0;
            output_idx <= '0;
            row_group <= 1'b0;
            protocol_error_o <= 1'b0;
            commit_pending_o <= 1'b0;
            pending_bank <= 1'b0;
            pending_version <= '0;
            active_bank_o <= 1'b0;
            active_version_o <= '0;
            transaction_bank <= 1'b0;
            transaction_mode_8x8 <= 1'b0;
            transaction_format_12 <= 1'b0;
            transaction_truncate <= 1'b0;
            transaction_wrap <= 1'b0;
            transaction_version <= '0;
            result_version <= '0;
            for (result_idx = 0; result_idx < 8; result_idx = result_idx + 1) begin
                result_real[result_idx] <= '0;
                result_imag[result_idx] <= '0;
                result_sat[result_idx] <= 1'b0;
            end
        end else begin
            if (commit_handshake && (state != ST_IDLE)
                    && !((state == ST_OUTPUT) && output_handshake
                         && (output_idx == transaction_last_index))) begin
                commit_pending_o <= 1'b1;
                pending_bank <= commit_bank_i;
                pending_version <= commit_version_i;
            end

            case (state)
                ST_IDLE: begin
                    symbol_write_idx <= '0;
                    compute_idx <= '0;
                    output_idx <= '0;
                    row_group <= 1'b0;
                    if (commit_handshake) begin
                        active_bank_o <= commit_bank_i;
                        active_version_o <= commit_version_i;
                        commit_pending_o <= 1'b0;
                    end else if (input_handshake) begin
                        protocol_error_o <= in_last_i
                            || (format_12_i && ((in_real_i[15:12] != {4{in_real_i[11]}})
                                               || (in_imag_i[15:12] != {4{in_imag_i[11]}})));
                        transaction_bank <= active_bank_o;
                        transaction_mode_8x8 <= mode_8x8_i;
                        transaction_format_12 <= format_12_i;
                        transaction_truncate <= truncate_i;
                        transaction_wrap <= wrap_i;
                        transaction_version <= active_version_o;
                        symbol_write_idx <= 3'd1;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    if (input_handshake) begin
                        if (in_last_i != (symbol_write_idx == transaction_last_index)
                                || (transaction_format_12
                                    && ((in_real_i[15:12] != {4{in_real_i[11]}})
                                     || (in_imag_i[15:12] != {4{in_imag_i[11]}})))) begin
                            protocol_error_o <= 1'b1;
                        end
                        if (symbol_write_idx == transaction_last_index) begin
                            compute_idx <= '0;
                            symbol_write_idx <= '0;
                            row_group <= 1'b0;
                            state <= ST_COMPUTE;
                        end else begin
                            symbol_write_idx <= symbol_write_idx + 1'b1;
                        end
                    end
                end

                ST_COMPUTE: begin
                    if (compute_idx == transaction_last_index) begin
                        state <= ST_CAPTURE;
                    end else begin
                        compute_idx <= compute_idx + 1'b1;
                    end
                end

                ST_CAPTURE: begin
                    for (capture_idx = 0; capture_idx < 4; capture_idx = capture_idx + 1) begin
                        if (transaction_format_12) begin
                            result_real[(row_group ? 4 : 0)+capture_idx] <= {{4{rounded_real_12[capture_idx][11]}}, rounded_real_12[capture_idx]};
                            result_imag[(row_group ? 4 : 0)+capture_idx] <= {{4{rounded_imag_12[capture_idx][11]}}, rounded_imag_12[capture_idx]};
                            result_sat[(row_group ? 4 : 0)+capture_idx] <= sat_real_12[capture_idx] || sat_imag_12[capture_idx];
                        end else begin
                            result_real[(row_group ? 4 : 0)+capture_idx] <= rounded_real[capture_idx];
                            result_imag[(row_group ? 4 : 0)+capture_idx] <= rounded_imag[capture_idx];
                            result_sat[(row_group ? 4 : 0)+capture_idx] <= sat_real[capture_idx] || sat_imag[capture_idx];
                        end
                    end
                    if (transaction_mode_8x8 && !row_group) begin
                        row_group <= 1'b1;
                        compute_idx <= '0;
                        state <= ST_COMPUTE;
                    end else begin
                        result_version <= transaction_version;
                        output_idx <= '0;
                        state <= ST_OUTPUT;
                    end
                end

                ST_OUTPUT: begin
                    if (output_handshake) begin
                        if (output_idx == transaction_last_index) begin
                            if (commit_pending_o) begin
                                active_bank_o <= pending_bank;
                                active_version_o <= pending_version;
                                commit_pending_o <= 1'b0;
                            end else if (commit_handshake) begin
                                active_bank_o <= commit_bank_i;
                                active_version_o <= commit_version_i;
                            end
                            state <= ST_IDLE;
                        end else begin
                            output_idx <= output_idx + 1'b1;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
