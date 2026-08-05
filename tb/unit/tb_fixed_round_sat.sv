`timescale 1ns/1ps

module tb_fixed_round_sat;
    logic signed [39:0] accumulator;
    logic signed [15:0] data_out;
    logic               saturated;
    logic signed [15:0] expected_data;
    logic               expected_saturated;

    integer vector_file;
    integer scan_result;
    integer test_count;
    integer error_count;

    fixed_round_sat dut (
        .acc_i(accumulator),
        .data_o(data_out),
        .saturated_o(saturated)
    );

`ifdef FSDB
    initial begin
        $fsdbDumpfile("build/vcs/waves/fixed_round_sat.fsdb");
        $fsdbDumpvars(0, tb_fixed_round_sat);
    end
`elsif VCD
    initial begin
        $dumpfile("build/vcs/waves/fixed_round_sat.vcd");
        $dumpvars(0, tb_fixed_round_sat);
    end
`endif

    initial begin
        test_count = 0;
        error_count = 0;
        vector_file = $fopen("build/rtl_vectors/fixed_round_sat.txt", "r");
        if (vector_file == 0) begin
            $fatal(1, "Cannot open fixed_round_sat vectors");
        end

        while (!$feof(vector_file)) begin
            scan_result = $fscanf(vector_file, "%d %d %d\n",
                                  accumulator, expected_data, expected_saturated);
            if (scan_result == 3) begin
                #1;
                test_count = test_count + 1;
                if ((data_out !== expected_data) || (saturated !== expected_saturated)) begin
                    error_count = error_count + 1;
                    $display("FAIL round[%0d] acc=%0d expected=(%0d,sat=%0d) actual=(%0d,sat=%0d)",
                             test_count, accumulator, expected_data, expected_saturated,
                             data_out, saturated);
                end
            end
        end
        $fclose(vector_file);

        if (error_count != 0) begin
            $fatal(1, "fixed_round_sat: %0d/%0d vectors failed", error_count, test_count);
        end
        $display("PASS fixed_round_sat: %0d vectors", test_count);
        $finish;
    end
endmodule
