`timescale 1ns/1ps

module tb_precoder_hot_update;
    logic clk, rst_n;
    logic cfg_valid, cfg_ready, cfg_bank;
    logic [2:0] cfg_row, cfg_col;
    logic signed [15:0] cfg_real, cfg_imag;
    logic [1:0] bank_complete;
    logic matrix_complete;
    logic commit_valid, commit_ready, commit_bank, commit_pending;
    logic [7:0] commit_version, active_version, out_version;
    logic active_bank;
    logic in_valid, in_ready, in_last;
    logic signed [15:0] in_real, in_imag;
    logic out_valid, out_ready, out_last, out_saturated;
    logic signed [15:0] out_real, out_imag;
    logic [2:0] out_ant_idx;
    logic busy, protocol_error;

    logic signed [15:0] matrix_real [0:1][0:15];
    logic signed [15:0] matrix_imag [0:1][0:15];
    logic signed [15:0] symbol_real [0:1][0:3];
    logic signed [15:0] symbol_imag [0:1][0:3];
    logic signed [15:0] expected_real [0:1][0:3];
    logic signed [15:0] expected_imag [0:1][0:3];
    logic expected_sat [0:1][0:3];

    integer vector_file, scan_result, case_count, case_id;
    integer idx, row, col, ant, timeout_count, errors;
    integer temp_real, temp_imag, temp_sat;

    precoder_core dut (
        .clk_i(clk), .rst_ni(rst_n),
        .mode_8x8_i(1'b0),
        .cfg_valid_i(cfg_valid), .cfg_ready_o(cfg_ready), .cfg_bank_i(cfg_bank),
        .cfg_row_i(cfg_row), .cfg_col_i(cfg_col), .cfg_real_i(cfg_real), .cfg_imag_i(cfg_imag),
        .bank_complete_o(bank_complete), .matrix_complete_o(matrix_complete),
        .commit_valid_i(commit_valid), .commit_ready_o(commit_ready),
        .commit_bank_i(commit_bank), .commit_version_i(commit_version),
        .commit_pending_o(commit_pending), .active_bank_o(active_bank),
        .active_version_o(active_version),
        .in_valid_i(in_valid), .in_ready_o(in_ready), .in_real_i(in_real),
        .in_imag_i(in_imag), .in_last_i(in_last),
        .out_valid_o(out_valid), .out_ready_i(out_ready), .out_real_o(out_real),
        .out_imag_o(out_imag), .out_ant_idx_o(out_ant_idx), .out_last_o(out_last),
        .out_saturated_o(out_saturated), .out_version_o(out_version),
        .busy_o(busy), .protocol_error_o(protocol_error)
    );

    always #5 clk = ~clk;

    task automatic write_coeff(input logic bank, input integer r, input integer c,
                               input logic signed [15:0] re,
                               input logic signed [15:0] im);
        begin
            @(negedge clk);
            cfg_bank = bank; cfg_row = r[2:0]; cfg_col = c[2:0];
            cfg_real = re; cfg_imag = im; cfg_valid = 1'b1;
            timeout_count = 0;
            while (!cfg_ready && timeout_count < 50) begin
                @(posedge clk); timeout_count = timeout_count + 1;
            end
            if (!cfg_ready) $fatal(1, "configuration timeout");
            @(posedge clk); @(negedge clk); cfg_valid = 1'b0;
        end
    endtask

    task automatic configure_bank(input integer bank, input integer case_idx);
        begin
            for (idx = 0; idx < 16; idx = idx + 1)
                write_coeff(bank, idx / 4, idx % 4,
                            matrix_real[case_idx][idx], matrix_imag[case_idx][idx]);
            #1;
            if (!bank_complete[bank]) $fatal(1, "bank %0d incomplete", bank);
        end
    endtask

    task automatic send_case(input integer case_idx);
        begin
            for (idx = 0; idx < 4; idx = idx + 1) begin
                @(negedge clk);
                in_real = symbol_real[case_idx][idx];
                in_imag = symbol_imag[case_idx][idx];
                in_last = (idx == 3); in_valid = 1'b1;
                timeout_count = 0;
                while (!in_ready && timeout_count < 100) begin
                    @(posedge clk); timeout_count = timeout_count + 1;
                end
                if (!in_ready) $fatal(1, "input timeout");
                @(posedge clk); @(negedge clk); in_valid = 1'b0; in_last = 1'b0;
            end
        end
    endtask

    task automatic check_case_outputs(input integer case_idx, input logic [7:0] version);
        begin
            out_ready = 1'b0;
            for (ant = 0; ant < 4; ant = ant + 1) begin
                timeout_count = 0;
                while (!out_valid && timeout_count < 100) begin
                    @(posedge clk); timeout_count = timeout_count + 1;
                end
                if (!out_valid) $fatal(1, "output timeout");
                #1;
                if ((out_ant_idx !== ant[2:0]) || (out_real !== expected_real[case_idx][ant])
                    || (out_imag !== expected_imag[case_idx][ant])
                    || (out_saturated !== expected_sat[case_idx][ant])
                    || (out_version !== version) || (out_last !== (ant == 3))) begin
                    errors = errors + 1;
                    $display("FAIL hot-update case=%0d ant=%0d version=%0d", case_idx, ant, out_version);
                end
                @(negedge clk); out_ready = 1'b1;
                @(posedge clk); @(negedge clk); out_ready = 1'b0;
            end
        end
    endtask

    task automatic commit_bank_now(input logic bank, input logic [7:0] version);
        begin
            @(negedge clk);
            commit_bank = bank;
            commit_version = version;
            commit_valid = 1'b1;
            timeout_count = 0;
            while (!commit_ready && timeout_count < 100) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            if (!commit_ready) $fatal(1, "commit timeout for bank %0d", bank);
            @(posedge clk);
            @(negedge clk);
            commit_valid = 1'b0;
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; cfg_valid = 0; cfg_bank = 0; cfg_row = 0; cfg_col = 0;
        cfg_real = 0; cfg_imag = 0; commit_valid = 0; commit_bank = 0; commit_version = 0;
        in_valid = 0; in_real = 0; in_imag = 0; in_last = 0; out_ready = 0; errors = 0;
`ifdef FSDB
        $fsdbDumpfile("build/vcs/waves/precoder_hot_update.fsdb");
        $fsdbDumpvars(0, tb_precoder_hot_update);
`elsif VCD
        $dumpfile("build/vcs/waves/precoder_hot_update.vcd");
        $dumpvars(0, tb_precoder_hot_update);
`endif
        #2; @(negedge clk); rst_n = 1;

        vector_file = $fopen("build/rtl_vectors/precoder_core.txt", "r");
        if (!vector_file) $fatal(1, "cannot open core vectors");
        scan_result = $fscanf(vector_file, "%d\n", case_count);
        for (case_id = 0; case_id < 2; case_id = case_id + 1) begin
            scan_result = $fscanf(vector_file, "%d\n", idx);
            for (row = 0; row < 16; row = row + 1) begin
                scan_result = $fscanf(vector_file, "%d %d\n", temp_real, temp_imag);
                matrix_real[case_id][row] = temp_real;
                matrix_imag[case_id][row] = temp_imag;
            end
            for (row = 0; row < 4; row = row + 1) begin
                scan_result = $fscanf(vector_file, "%d %d\n", temp_real, temp_imag);
                symbol_real[case_id][row] = temp_real;
                symbol_imag[case_id][row] = temp_imag;
            end
            for (row = 0; row < 4; row = row + 1) begin
                scan_result = $fscanf(vector_file, "%d %d %d\n",
                                      temp_real, temp_imag, temp_sat);
                expected_real[case_id][row] = temp_real;
                expected_imag[case_id][row] = temp_imag;
                expected_sat[case_id][row] = temp_sat;
            end
        end
        $fclose(vector_file);

        // Complete Bank 1 first so coverage observes the bank1-only state, then
        // prepare active Bank 0 for the first transaction.
        configure_bank(1, 1);
        configure_bank(0, 0);

        // Bank 0 is active. Start case 0, then update inactive Bank 1 while output is stalled.
        send_case(0);
        configure_bank(1, 1);
        commit_bank_now(1'b1, 8'h2A);
        if (!commit_pending) $display("INFO: commit accepted and pending at vector boundary");
        check_case_outputs(0, 8'h00);
        #1;
        if ((active_bank !== 1'b1) || (active_version !== 8'h2A))
            $fatal(1, "Bank 1 did not become active after final output handshake");

        send_case(1);
        check_case_outputs(1, 8'h2A);

        // Return to the already complete Bank 0 while idle. This covers the
        // immediate commit path and the reverse 1 -> 0 bank transition.
        if (busy) $fatal(1, "core was not idle before reverse commit");
        commit_bank_now(1'b0, 8'hA5);
        #1;
        if ((active_bank !== 1'b0) || (active_version !== 8'hA5) || commit_pending)
            $fatal(1, "idle commit did not immediately reactivate Bank 0");
        send_case(0);
        check_case_outputs(0, 8'hA5);

        // Exercise a zero-version idle commit as a distinct metadata class.
        commit_bank_now(1'b1, 8'h00);
        #1;
        if ((active_bank !== 1'b1) || (active_version !== 8'h00) || commit_pending)
            $fatal(1, "zero-version idle commit did not activate Bank 1");

        // Commit Bank 0 while Bank 1 is busy. The current transaction must keep
        // version zero, and the high version becomes active only at its boundary.
        send_case(1);
        commit_bank_now(1'b0, 8'hA5);
        if (!commit_pending)
            $fatal(1, "busy Bank 0 commit was not marked pending");
        check_case_outputs(1, 8'h00);
        #1;
        if ((active_bank !== 1'b0) || (active_version !== 8'hA5) || commit_pending)
            $fatal(1, "busy Bank 0 commit did not apply at the vector boundary");

        if (errors != 0) $fatal(1, "hot update: %0d output errors", errors);
        $display("PASS precoder_hot_update: busy/idle commit, bank round-trip, and version tracking");
        $finish;
    end
endmodule
