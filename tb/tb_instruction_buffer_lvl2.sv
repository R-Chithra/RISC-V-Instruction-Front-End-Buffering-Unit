`timescale 1ns/1ps

module tb_instruction_buffer_lvl2;

    localparam int DEPTH = 4;

    logic clk;
    logic reset;

    // Decode side
    logic instr_in_valid;
    logic instr_is_long;
    logic instr_in_stall;

    // Execute side
    logic exec_busy;
    logic exec_will_free_next;
    logic instr_out_valid;

    // State
    logic [$clog2(DEPTH+1)-1:0] count;

    /* ------------------------------------------------------------
       DUT
       ------------------------------------------------------------ */
    instruction_buffer_lvl2 #(
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .reset(reset),

        .instr_in_valid(instr_in_valid),
        .instr_is_long(instr_is_long),
        .instr_in_stall(instr_in_stall),

        .exec_busy(exec_busy),
        .exec_will_free_next(exec_will_free_next),
        .instr_out_valid(instr_out_valid),

        .count(count)
    );

    /* ------------------------------------------------------------
       MONITOR (time-correct)
       ------------------------------------------------------------ */
    ibuf_lvl2_monitor #(
        .DEPTH(DEPTH)
    ) monitor (
        .clk(clk),
        .reset(reset),

        .instr_in_valid(instr_in_valid),
        .instr_is_long(instr_is_long),
        .instr_in_stall(instr_in_stall),

        .exec_busy(exec_busy),
        .exec_will_free_next(exec_will_free_next),

        .bypass_allowed(dut.bypass_allowed),
        .push_allowed(dut.push_allowed),
        .pop_allowed(dut.pop_allowed),

        .count(count)
    );

    /* ------------------------------------------------------------
       Clock
       ------------------------------------------------------------ */
    always #5 clk = ~clk;

    /* ------------------------------------------------------------
       Drive task (negedge ONLY)
       ------------------------------------------------------------ */
    task drive(
        input logic v,
        input logic l,
        input logic b,
        input logic f
    );
        @(negedge clk);
        instr_in_valid      <= v;
        instr_is_long       <= l;
        exec_busy           <= b;
        exec_will_free_next <= f;
    endtask

    /* ------------------------------------------------------------
       Reset
       ------------------------------------------------------------ */
    initial begin
        clk = 0;
        instr_in_valid      = 0;
        instr_is_long       = 0;
        exec_busy           = 0;
        exec_will_free_next = 0;

        reset = 1;
        repeat (2) @(posedge clk);
        reset = 0;
    end

    /* ------------------------------------------------------------
       OUTPUT TABLE HEADER
       ------------------------------------------------------------ */
    initial begin
        $display(" time | in | long | busy | free | push | pop | bypass | count");
        $display("-------------------------------------------------------------");
    end

    /* ------------------------------------------------------------
       OUTPUT TABLE (PRINT AFTER STATE UPDATE)
       ------------------------------------------------------------ */
    always @(posedge clk) begin
        if (!reset) begin
            $display("%5t |  %0d |   %0d  |  %0d   |  %0d   |   %0d  |  %0d |   %0d   |   %0d",
                $time,
                instr_in_valid,
                instr_is_long,
                exec_busy,
                exec_will_free_next,
                dut.push_allowed,
                dut.pop_allowed,
                dut.bypass_allowed,
                count
            );
        end
    end

    /* ------------------------------------------------------------
       Stimulus
       ------------------------------------------------------------ */
    initial begin
        @(negedge clk);

        // 1. Short, exec free → bypass
        drive(1, 0, 0, 0);
        drive(0, 0, 0, 0);

        // 2. Short, exec busy → push
        drive(1, 0, 1, 0);
        drive(0, 0, 1, 0);

        // 3. Lookahead pop
        drive(0, 0, 1, 1);
        drive(0, 0, 0, 0);

        // 4. Long → push
        drive(1, 1, 1, 0);
        drive(0, 0, 1, 0);

        // 5. Push + pop
        drive(1, 0, 1, 1);
        drive(0, 0, 0, 0);

        // 6. Fill buffer
        repeat (DEPTH) begin
            drive(1, 1, 1, 0);
            drive(0, 0, 1, 0);
        end

        // 7. Stall case
        drive(1, 1, 1, 0);
        drive(0, 0, 1, 0);

        // 8. Drain buffer
        repeat (DEPTH) begin
            drive(0, 0, 0, 0);
        end

        #20;
        $display("SIM PASSED — LEVEL-2 VERIFIED");
        $finish;
    end

    /* ------------------------------------------------------------
       VCD
       ------------------------------------------------------------ */
    initial begin
        $dumpfile("instruction_buffer_lvl2.vcd");
        $dumpvars(0, tb_instruction_buffer_lvl2);
    end

endmodule
