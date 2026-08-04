`timescale 1ns/1ps

module tb_complex_mac;
    logic clk;
    logic rst_n;
    logic clear;
    logic enable;
    logic signed [15:0] a_real;
    logic signed [15:0] a_imag;
    logic signed [15:0] b_real;
    logic signed [15:0] b_imag;
    logic signed [39:0] acc_real;
    logic signed [39:0] acc_imag;
    logic signed [39:0] expected_real;
    logic signed [39:0] expected_imag;

    integer vector_file;
    integer scan_result;
    integer test_count;
    integer error_count;

    complex_mac dut (
        .clk_i(clk),
        .rst_ni(rst_n),
        .clear_i(clear),
        .enable_i(enable),
        .a_real_i(a_real),
        .a_imag_i(a_imag),
        .b_real_i(b_real),
        .b_imag_i(b_imag),
        .acc_real_o(acc_real),
        .acc_imag_o(acc_imag)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        clear = 1'b0;
        enable = 1'b0;
        a_real = '0;
        a_imag = '0;
        b_real = '0;
        b_imag = '0;
        test_count = 0;
        error_count = 0;

        #2;
        if ((acc_real !== 0) || (acc_imag !== 0)) begin
            $fatal(1, "complex_mac asynchronous reset failed");
        end
        @(negedge clk);
        rst_n = 1'b1;

        vector_file = $fopen("build/rtl_vectors/complex_mac.txt", "r");
        if (vector_file == 0) begin
            $fatal(1, "Cannot open complex_mac vectors");
        end

        while (!$feof(vector_file)) begin
            scan_result = $fscanf(vector_file, "%d %d %d %d %d %d %d %d\n",
                                  clear, enable, a_real, a_imag, b_real, b_imag,
                                  expected_real, expected_imag);
            if (scan_result == 8) begin
                @(posedge clk);
                #1;
                test_count = test_count + 1;
                if ((acc_real !== expected_real) || (acc_imag !== expected_imag)) begin
                    error_count = error_count + 1;
                    $display("FAIL mac[%0d] clear=%0d enable=%0d expected=(%0d,%0d) actual=(%0d,%0d)",
                             test_count, clear, enable, expected_real, expected_imag,
                             acc_real, acc_imag);
                end
                @(negedge clk);
            end
        end
        $fclose(vector_file);

        if (error_count != 0) begin
            $fatal(1, "complex_mac: %0d/%0d vectors failed", error_count, test_count);
        end
        $display("PASS complex_mac: %0d vectors", test_count);
        $finish;
    end
endmodule

