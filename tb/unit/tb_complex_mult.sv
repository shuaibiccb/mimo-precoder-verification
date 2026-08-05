`timescale 1ns/1ps

module tb_complex_mult;
    logic signed [15:0] a_real;
    logic signed [15:0] a_imag;
    logic signed [15:0] b_real;
    logic signed [15:0] b_imag;
    logic signed [32:0] p_real;
    logic signed [32:0] p_imag;
    logic signed [32:0] expected_real;
    logic signed [32:0] expected_imag;

    integer vector_file;
    integer scan_result;
    integer test_count;
    integer error_count;

    complex_mult dut (
        .a_real_i(a_real),
        .a_imag_i(a_imag),
        .b_real_i(b_real),
        .b_imag_i(b_imag),
        .p_real_o(p_real),
        .p_imag_o(p_imag)
    );

`ifdef FSDB
    initial begin
        $fsdbDumpfile("build/vcs/waves/complex_mult.fsdb");
        $fsdbDumpvars(0, tb_complex_mult);
    end
`elsif VCD
    initial begin
        $dumpfile("build/vcs/waves/complex_mult.vcd");
        $dumpvars(0, tb_complex_mult);
    end
`endif

    initial begin
        test_count = 0;
        error_count = 0;
        vector_file = $fopen("build/rtl_vectors/complex_mult.txt", "r");
        if (vector_file == 0) begin
            $fatal(1, "Cannot open complex_mult vectors");
        end

        while (!$feof(vector_file)) begin
            scan_result = $fscanf(vector_file, "%d %d %d %d %d %d\n",
                                  a_real, a_imag, b_real, b_imag,
                                  expected_real, expected_imag);
            if (scan_result == 6) begin
                #1;
                test_count = test_count + 1;
                if ((p_real !== expected_real) || (p_imag !== expected_imag)) begin
                    error_count = error_count + 1;
                    $display("FAIL mult[%0d] a=(%0d,%0d) b=(%0d,%0d) expected=(%0d,%0d) actual=(%0d,%0d)",
                             test_count, a_real, a_imag, b_real, b_imag,
                             expected_real, expected_imag, p_real, p_imag);
                end
            end
        end
        $fclose(vector_file);

        if (error_count != 0) begin
            $fatal(1, "complex_mult: %0d/%0d vectors failed", error_count, test_count);
        end
        $display("PASS complex_mult: %0d vectors", test_count);
        $finish;
    end
endmodule
