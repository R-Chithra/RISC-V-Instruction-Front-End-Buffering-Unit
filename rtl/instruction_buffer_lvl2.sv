module instruction_buffer_lvl2 #(
    parameter int DEPTH = 4
)(
    input  logic        clk,
    input  logic        reset,

    // Decode side
    input  logic        instr_in_valid,
    input  logic        instr_is_long,
    output logic        instr_in_stall,

    // Execute side
    input  logic        exec_busy,
    input  logic        exec_will_free_next,
    output logic        instr_out_valid,

    // Debug
    output logic [$clog2(DEPTH+1)-1:0] count
);

    /* ------------------------------------------------------------
       Combinational signals
       ------------------------------------------------------------ */
    logic exec_can_accept;
    logic bypass_allowed;
    logic push_allowed;
    logic pop_allowed;

    assign exec_can_accept =
        (~exec_busy) | exec_will_free_next;

    /* ------------------------------------------------------------
       Stall logic
       ------------------------------------------------------------ */
    assign instr_in_stall = (count == DEPTH);

    /* ------------------------------------------------------------
       Bypass logic
       ------------------------------------------------------------ */
    assign bypass_allowed =
        instr_in_valid &&
        ~instr_is_long &&
        (count == 0) &&
        exec_can_accept;

    /* ------------------------------------------------------------
       Push logic
       ------------------------------------------------------------ */
    assign push_allowed =
        instr_in_valid &&
        ~instr_in_stall &&
        ~bypass_allowed;

    /* ------------------------------------------------------------
       Pop logic
       ------------------------------------------------------------ */
    assign pop_allowed =
        (count > 0) &&
        exec_can_accept;

    /* ------------------------------------------------------------
       Output valid
       ------------------------------------------------------------ */
    assign instr_out_valid =
        pop_allowed || bypass_allowed;

    /* ------------------------------------------------------------
       Count state update (ONLY PLACE)
       ------------------------------------------------------------ */
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= '0;
        end
        else begin
            case ({push_allowed, pop_allowed})
                2'b10: count <= count + 1; // push
                2'b01: count <= count - 1; // pop
                default: count <= count;   // same / idle
            endcase
        end
    end

endmodule
