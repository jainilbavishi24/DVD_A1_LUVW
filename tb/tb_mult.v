`timescale 1ns/1ps

module tb_mult;
    reg        clk;
    reg        rst_n;
    reg  [3:0] a;
    reg  [3:0] b;
    wire [7:0] p;
    integer    i;
    integer    errors;
    reg  [7:0] expected;

    mult_array dut (
        .clk(clk), .rst_n(rst_n), .a(a), .b(b), .p(p)
    );

    // 10 ns clock period.
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);

        rst_n = 1'b0;
        a = 4'b0;
        b = 4'b0;
        errors = 0;

        // Reset remains asserted for the first two rising clock edges.
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Apply each input before edge 1, then check after edge 2.
        for (i = 0; i < 256; i = i + 1) begin
            @(negedge clk);
            a = i / 16;
            b = i % 16;
            expected = (i / 16) * (i % 16);

            repeat (2) @(posedge clk);
`ifdef GATE_LEVEL
            // Standard-cell UNIT_DELAY=#1 updates Q in the same timestep as
            // a #1 testbench sample. Avoid that simulator scheduling race.
            #2;
`else
            #1;
`endif
            if (p !== expected) begin
                $display("MISMATCH: a=%0d b=%0d expected=%0d got=%0d at %0t", a, b, expected, p, $time);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: 256 vectors checked, 0 errors");
        else
            $display("FAIL: 256 vectors checked, %0d errors", errors);
        $finish;
    end
endmodule
