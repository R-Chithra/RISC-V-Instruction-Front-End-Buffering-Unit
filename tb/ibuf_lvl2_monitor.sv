module ibuf_lvl2_monitor #(
    parameter int DEPTH = 4
)(
    input logic clk,
    input logic reset,

    input logic instr_in_valid,
    input logic instr_is_long,
    input logic instr_in_stall,

    input logic exec_busy,
    input logic exec_will_free_next,

    input logic bypass_allowed,
    input logic push_allowed,
    input logic pop_allowed,

    input logic [$clog2(DEPTH+1)-1:0] count
);

    logic [$clog2(DEPTH+1)-1:0] count_prev;
    logic [$clog2(DEPTH+1)-1:0] expected_prev;

    always @(posedge clk) begin
        if (reset) begin
            count_prev    <= count;
            expected_prev <= count;
        end
        else begin
            /* Check LAST cycle’s expectation */
            if (count !== expected_prev) begin
                $display("MONITOR ERROR: count mismatch");
                $display("  expected=%0d actual=%0d", expected_prev, count);
                $finish(1);
            end

            /* Sanity checks */
            if (instr_is_long && !instr_in_valid) begin
                $display("MONITOR ERROR: instr_is_long without instr_in_valid");
                $finish(1);
            end

            if (count > DEPTH) begin
                $display("MONITOR ERROR: count overflow");
                $finish(1);
            end

            if (count == DEPTH && !instr_in_stall) begin
                $display("MONITOR ERROR: full buffer but no stall");
                $finish(1);
            end

            if (pop_allowed && !(~exec_busy || exec_will_free_next)) begin
                $display("MONITOR ERROR: pop without exec_can_accept");
                $finish(1);
            end

            /* Compute NEXT expected value */
            expected_prev <= count
                             + (push_allowed ? 1 : 0)
                             - (pop_allowed  ? 1 : 0);

            count_prev <= count;
        end
    end

endmodule
