`timescale 1ns/1ps

module tb_precoder_core;
    logic clk;
    logic rst_n;
    logic cfg_valid;
    logic cfg_ready;
    logic cfg_bank;
    logic [1:0] cfg_row;
    logic [1:0] cfg_col;
    logic signed [15:0] cfg_real;
    logic signed [15:0] cfg_imag;
    logic [1:0] bank_complete;
    logic matrix_complete;
    logic commit_valid;
    logic commit_ready;
    logic commit_bank;
    logic [7:0] commit_version;
    logic commit_pending;
    logic active_bank;
    logic [7:0] active_version;
    logic in_valid;
    logic in_ready;
    logic signed [15:0] in_real;
    logic signed [15:0] in_imag;
    logic in_last;
    logic out_valid;
    logic out_ready;
    logic signed [15:0] out_real;
    logic signed [15:0] out_imag;
    logic [1:0] out_ant_idx;
    logic out_last;
    logic out_saturated;
    logic [7:0] out_version;
    logic busy;
    logic protocol_error;

    logic signed [15:0] matrix_real [0:15];
    logic signed [15:0] matrix_imag [0:15];
    logic signed [15:0] symbol_real [0:3];
    logic signed [15:0] symbol_imag [0:3];
    logic signed [15:0] expected_real [0:3];
    logic signed [15:0] expected_imag [0:3];
    logic               expected_sat [0:3];

    logic previous_stall;
    logic signed [15:0] previous_out_real;
    logic signed [15:0] previous_out_imag;
    logic [1:0]         previous_out_idx;
    logic               previous_out_last;
    logic               previous_out_sat;

    integer vector_file;
    integer scan_result;
    integer case_count;
    integer case_id;
    integer case_index;
    integer element;
    integer antenna;
    integer error_count;
    integer timeout_count;

    precoder_core dut (
        .clk_i(clk),
        .rst_ni(rst_n),
        .cfg_valid_i(cfg_valid),
        .cfg_ready_o(cfg_ready),
        .cfg_bank_i(cfg_bank),
        .cfg_row_i(cfg_row),
        .cfg_col_i(cfg_col),
        .cfg_real_i(cfg_real),
        .cfg_imag_i(cfg_imag),
        .bank_complete_o(bank_complete),
        .matrix_complete_o(matrix_complete),
        .commit_valid_i(commit_valid),
        .commit_ready_o(commit_ready),
        .commit_bank_i(commit_bank),
        .commit_version_i(commit_version),
        .commit_pending_o(commit_pending),
        .active_bank_o(active_bank),
        .active_version_o(active_version),
        .in_valid_i(in_valid),
        .in_ready_o(in_ready),
        .in_real_i(in_real),
        .in_imag_i(in_imag),
        .in_last_i(in_last),
        .out_valid_o(out_valid),
        .out_ready_i(out_ready),
        .out_real_o(out_real),
        .out_imag_o(out_imag),
        .out_ant_idx_o(out_ant_idx),
        .out_last_o(out_last),
        .out_saturated_o(out_saturated),
        .out_version_o(out_version),
        .busy_o(busy),
        .protocol_error_o(protocol_error)
    );

`ifdef FSDB
    initial begin
        $fsdbDumpfile("build/vcs/waves/precoder_core.fsdb");
        $fsdbDumpvars(0, tb_precoder_core);
    end
`elsif VCD
    initial begin
        $dumpfile("build/vcs/waves/precoder_core.vcd");
        $dumpvars(0, tb_precoder_core);
    end
`endif

    always #5 clk = ~clk;

    task automatic apply_reset;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            #1;
            if ((busy !== 1'b0) || (out_valid !== 1'b0)
                    || (matrix_complete !== 1'b0) || (bank_complete !== 2'b00)) begin
                $fatal(1, "reset did not clear core state");
            end
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task automatic write_coefficient(
        input logic bank_value,
        input integer row,
        input integer col,
        input logic signed [15:0] real_value,
        input logic signed [15:0] imag_value
    );
        begin
            @(negedge clk);
            cfg_bank  = bank_value;
            cfg_row   = row[1:0];
            cfg_col   = col[1:0];
            cfg_real  = real_value;
            cfg_imag  = imag_value;
            cfg_valid = 1'b1;
            timeout_count = 0;
            while (!cfg_ready && timeout_count < 20) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            if (!cfg_ready) begin
                $fatal(1, "configuration handshake timeout");
            end
            @(posedge clk);
            @(negedge clk);
            cfg_valid = 1'b0;
        end
    endtask

    task automatic configure_loaded_matrix_bank(input logic bank_value);
        integer idx;
        begin
            for (idx = 0; idx < 16; idx = idx + 1) begin
                write_coefficient(bank_value, idx / 4, idx % 4,
                                  matrix_real[idx], matrix_imag[idx]);
            end
            #1;
            if (!bank_complete[bank_value]) begin
                $fatal(1, "bank %0d did not become complete after 16 writes",
                       bank_value);
            end
        end
    endtask

    task automatic configure_loaded_matrix;
        begin
            configure_loaded_matrix_bank(1'b0);
        end
    endtask

    task automatic commit_matrix_bank(
        input logic bank_value,
        input logic [7:0] version_value
    );
        begin
            @(negedge clk);
            commit_bank = bank_value;
            commit_version = version_value;
            commit_valid = 1'b1;
            timeout_count = 0;
            while (!commit_ready && timeout_count < 50) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            if (!commit_ready) begin
                $fatal(1, "commit timeout for bank %0d", bank_value);
            end
            @(posedge clk);
            @(negedge clk);
            commit_valid = 1'b0;
        end
    endtask

    task automatic probe_stalled_interfaces;
        begin
            // No complete matrix exists, so both payloads must remain stalled.
            // Reset is the only legal way to cancel these permanently blocked
            // transfers without violating the ready/valid stability contract.
            @(negedge clk);
            in_real = 16'sd1234;
            in_imag = -16'sd567;
            in_last = 1'b0;
            in_valid = 1'b1;
            commit_bank = 1'b1;
            commit_version = 8'h5A;
            commit_valid = 1'b1;
            repeat (3) @(posedge clk);
            if (in_ready || commit_ready) begin
                $fatal(1, "incomplete matrices unexpectedly accepted traffic");
            end
            @(negedge clk);
            rst_n = 1'b0;
            in_valid = 1'b0;
            in_last = 1'b0;
            commit_valid = 1'b0;
            #1;
            if ((busy !== 1'b0) || (out_valid !== 1'b0)
                    || (matrix_complete !== 1'b0)
                    || (bank_complete !== 2'b00)) begin
                $fatal(1, "reset did not clear stalled interface probe");
            end
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task automatic start_cfg_stall_while_busy;
        begin
            if (!busy) $fatal(1, "configuration stall probe requires busy core");
            @(negedge clk);
            cfg_bank = active_bank;
            cfg_row = 2'd0;
            cfg_col = 2'd0;
            cfg_real = matrix_real[0];
            cfg_imag = matrix_imag[0];
            cfg_valid = 1'b1;
            repeat (3) @(posedge clk);
            if (cfg_ready) $fatal(1, "active bank became writable while busy");
        end
    endtask

    task automatic finish_cfg_stall_probe;
        begin
            timeout_count = 0;
            while (!cfg_ready && timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end
            if (!cfg_ready) begin
                $fatal(1, "stalled configuration did not become writable");
            end
            @(posedge clk);
            @(negedge clk);
            cfg_valid = 1'b0;
        end
    endtask

    task automatic send_symbol(
        input integer idx,
        input integer gap_cycles,
        input logic malformed_first_last
    );
        integer gap;
        begin
            for (gap = 0; gap < gap_cycles; gap = gap + 1) begin
                @(posedge clk);
            end
            @(negedge clk);
            in_real  = symbol_real[idx];
            in_imag  = symbol_imag[idx];
            in_last  = (idx == 3) || ((idx == 0) && malformed_first_last);
            in_valid = 1'b1;
            timeout_count = 0;
            while (!in_ready && timeout_count < 50) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            if (!in_ready) begin
                $fatal(1, "input handshake timeout for symbol %0d", idx);
            end
            @(posedge clk);
            @(negedge clk);
            in_valid = 1'b0;
            in_last  = 1'b0;
        end
    endtask

    task automatic check_one_output(
        input integer expected_idx,
        input integer stall_cycles,
        input logic [7:0] expected_version
    );
        integer stall;
        begin
            @(negedge clk);
            out_ready = 1'b0;
            timeout_count = 0;
            while (!out_valid && timeout_count < 100) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            if (!out_valid) begin
                $fatal(1, "output timeout for antenna %0d", expected_idx);
            end

            #1;
            if ((out_ant_idx !== expected_idx[1:0])
                    || (out_real !== expected_real[expected_idx])
                    || (out_imag !== expected_imag[expected_idx])
                    || (out_saturated !== expected_sat[expected_idx])
                    || (out_version !== expected_version)
                    || (out_last !== (expected_idx == 3))) begin
                error_count = error_count + 1;
                $display("FAIL core case=%0d ant=%0d expected=(%0d,%0d,sat=%0d,last=%0d) actual=(%0d,%0d,sat=%0d,last=%0d,idx=%0d)",
                         case_id, expected_idx, expected_real[expected_idx],
                         expected_imag[expected_idx], expected_sat[expected_idx],
                         (expected_idx == 3), out_real, out_imag, out_saturated,
                         out_last, out_ant_idx);
            end

            for (stall = 0; stall < stall_cycles; stall = stall + 1) begin
                @(posedge clk);
                #1;
                if (!out_valid) begin
                    $fatal(1, "out_valid dropped during backpressure");
                end
            end

            @(negedge clk);
            out_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            out_ready = 1'b0;
        end
    endtask

    task automatic reset_mid_vector_test;
        integer idx;
        begin
            for (idx = 0; idx < 16; idx = idx + 1) begin
                matrix_real[idx] = (idx / 4 == idx % 4) ? 16'sd16384 : 16'sd0;
                matrix_imag[idx] = 16'sd0;
            end
            configure_loaded_matrix();
            symbol_real[0] = 16'sd4096;
            symbol_imag[0] = -16'sd2048;
            symbol_real[1] = -16'sd8192;
            symbol_imag[1] = 16'sd1024;
            send_symbol(0, 0, 1'b0);
            send_symbol(1, 1, 1'b0);
            apply_reset();
            repeat (3) @(posedge clk);
            if (out_valid || busy || matrix_complete) begin
                $fatal(1, "reset failed to cancel partial vector");
            end
        end
    endtask

    task automatic reset_compute_capture_test;
        integer idx;
        begin
            // Reset once while the MAC pipeline is computing.
            configure_loaded_matrix();
            for (idx = 0; idx < 4; idx = idx + 1) begin
                send_symbol(idx, 0, 1'b0);
            end
            apply_reset();

            // Repeat and wait until the compute loop advances into capture.
            configure_loaded_matrix();
            for (idx = 0; idx < 4; idx = idx + 1) begin
                send_symbol(idx, 0, 1'b0);
            end
            repeat (4) @(posedge clk);
            apply_reset();
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            previous_stall    <= 1'b0;
            previous_out_real <= '0;
            previous_out_imag <= '0;
            previous_out_idx  <= '0;
            previous_out_last <= 1'b0;
            previous_out_sat  <= 1'b0;
        end else begin
            if (previous_stall) begin
                if ((out_valid !== 1'b1)
                        || (out_real !== previous_out_real)
                        || (out_imag !== previous_out_imag)
                        || (out_ant_idx !== previous_out_idx)
                        || (out_last !== previous_out_last)
                        || (out_saturated !== previous_out_sat)) begin
                    $fatal(1, "output payload changed while stalled");
                end
            end
            if (out_last && (out_ant_idx != 2'd3)) begin
                $fatal(1, "out_last asserted on the wrong antenna");
            end
            previous_stall    <= out_valid && !out_ready;
            previous_out_real <= out_real;
            previous_out_imag <= out_imag;
            previous_out_idx  <= out_ant_idx;
            previous_out_last <= out_last;
            previous_out_sat  <= out_saturated;
        end
    end

    initial begin
        clk          = 1'b0;
        rst_n        = 1'b0;
        cfg_valid    = 1'b0;
        cfg_bank     = 1'b0;
        cfg_row      = '0;
        cfg_col      = '0;
        cfg_real     = '0;
        cfg_imag     = '0;
        commit_valid = 1'b0;
        commit_bank  = 1'b0;
        commit_version = '0;
        in_valid     = 1'b0;
        in_real      = '0;
        in_imag      = '0;
        in_last      = 1'b0;
        out_ready    = 1'b0;
        error_count  = 0;

        #2;
        if ((busy !== 1'b0) || (out_valid !== 1'b0)) begin
            $fatal(1, "asynchronous reset failed at startup");
        end
        @(negedge clk);
        rst_n = 1'b1;

        probe_stalled_interfaces();
        reset_mid_vector_test();
        reset_compute_capture_test();

        vector_file = $fopen("build/rtl_vectors/precoder_core.txt", "r");
        if (vector_file == 0) begin
            $fatal(1, "Cannot open precoder_core vectors");
        end
        scan_result = $fscanf(vector_file, "%d\n", case_count);
        if (scan_result != 1) begin
            $fatal(1, "Cannot read precoder_core case count");
        end

        for (case_index = 0; case_index < case_count; case_index = case_index + 1) begin
            scan_result = $fscanf(vector_file, "%d\n", case_id);
            if (scan_result != 1) begin
                $fatal(1, "Cannot read case id at index %0d", case_index);
            end
            for (element = 0; element < 16; element = element + 1) begin
                scan_result = $fscanf(vector_file, "%d %d\n",
                                      matrix_real[element], matrix_imag[element]);
                if (scan_result != 2) $fatal(1, "Malformed matrix vector");
            end
            for (element = 0; element < 4; element = element + 1) begin
                scan_result = $fscanf(vector_file, "%d %d\n",
                                      symbol_real[element], symbol_imag[element]);
                if (scan_result != 2) $fatal(1, "Malformed symbol vector");
            end
            for (element = 0; element < 4; element = element + 1) begin
                scan_result = $fscanf(vector_file, "%d %d %d\n",
                                      expected_real[element], expected_imag[element],
                                      expected_sat[element]);
                if (scan_result != 3) $fatal(1, "Malformed expected vector");
            end

            configure_loaded_matrix();
            for (element = 0; element < 4; element = element + 1) begin
                send_symbol(element, (case_id + element) % 3,
                            (case_id == 0) && (element == 0));
            end
            for (antenna = 0; antenna < 4; antenna = antenna + 1) begin
                check_one_output(antenna, (case_id + antenna) % 4, 8'h00);
            end

            if ((case_id == 0) && !protocol_error) begin
                $fatal(1, "malformed in_last did not set protocol_error");
            end
            if ((case_id != 0) && protocol_error) begin
                $fatal(1, "protocol_error did not clear at the next vector");
            end
        end
        $fclose(vector_file);

        // Build Bank 1 first after reset to cover the bank1-only completeness
        // state, then exercise high/low nonzero versions and both bank switches.
        apply_reset();
        configure_loaded_matrix_bank(1'b1);
        commit_matrix_bank(1'b1, 8'hA5);
        for (element = 0; element < 4; element = element + 1) begin
            send_symbol(element, element % 2, 1'b0);
        end
        write_coefficient(1'b0, 0, 0, matrix_real[0], matrix_imag[0]);
        start_cfg_stall_while_busy();
        for (antenna = 0; antenna < 4; antenna = antenna + 1) begin
            check_one_output(antenna, antenna % 3, 8'hA5);
        end
        finish_cfg_stall_probe();

        configure_loaded_matrix_bank(1'b0);
        commit_matrix_bank(1'b0, 8'h2A);
        for (element = 0; element < 4; element = element + 1) begin
            send_symbol(element, (element + 1) % 2, 1'b0);
        end
        start_cfg_stall_while_busy();
        commit_matrix_bank(1'b1, 8'h00);
        if (!commit_pending) begin
            $fatal(1, "busy commit did not enter pending state");
        end
        for (antenna = 0; antenna < 4; antenna = antenna + 1) begin
            check_one_output(antenna, (antenna + 1) % 3, 8'h2A);
        end
        #1;
        if ((active_bank !== 1'b1) || (active_version !== 8'h00)
                || commit_pending) begin
            $fatal(1, "pending Bank1 commit did not apply at vector boundary");
        end
        finish_cfg_stall_probe();
        for (element = 0; element < 4; element = element + 1) begin
            send_symbol(element, element % 2, 1'b0);
        end
        commit_matrix_bank(1'b0, 8'hC3);
        if (!commit_pending) begin
            $fatal(1, "busy Bank0 commit did not enter pending state");
        end
        for (antenna = 0; antenna < 4; antenna = antenna + 1) begin
            check_one_output(antenna, antenna % 2, 8'h00);
        end
        #1;
        if ((active_bank !== 1'b0) || (active_version !== 8'hC3)
                || commit_pending) begin
            $fatal(1, "pending Bank0 commit did not apply at vector boundary");
        end

        if (error_count != 0) begin
            $fatal(1, "precoder_core: %0d output comparisons failed", error_count);
        end
        $display("PASS precoder_core: %0d cases, %0d output comparisons",
                 case_count, case_count * 4);
        $finish;
    end

endmodule
