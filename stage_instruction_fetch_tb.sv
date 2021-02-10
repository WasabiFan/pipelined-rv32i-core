`timescale 1ns/1ps

module stage_instruction_fetch_tb();
    initial begin
        $dumpfile("stage_instruction_fetch_tb.vcd");
        $dumpvars(0,stage_instruction_fetch_tb);
    end

    logic clk, reset;
    logic enable;
    logic [XLEN-1:0] pc;
    logic [XLEN-1:0] mem_r_data;

    logic [XLEN-1:0] mem_addr;
    logic is_complete;
    logic [ILEN-1:0] instr_bits;

    stage_instruction_fetch dut (clk, reset, enable, pc, mem_r_data, is_complete, mem_addr, instr_bits);

    // Set up the clock
    parameter CLOCK_PERIOD=100;
    initial begin
        clk <= 0;
        forever #(CLOCK_PERIOD/2) clk <= ~clk;
    end

    initial begin
        @(posedge clk); reset <= 1;                     enable <= 0;
        @(posedge clk); reset <= 0; pc <= 32'hCAFEBABE;              mem_r_data <= 32'h00000000;
        // Confirm it does nothing
        @(posedge clk);
        @(posedge clk);

        // Try normal operation with an ADD (not LOAD)
        @(posedge clk);             pc <= 32'hDEADBEEF; enable <= 1;
        @(posedge clk);                                              mem_r_data <= 32'hfff78793;
        // After read should have finished, disable and validate the outputs hold
        @(posedge clk);                                 enable <= 0; mem_r_data <= 32'hXXXXXXXX;
        @(posedge clk);
        @(posedge clk);

        // Re-enable with a new instruction, this time a LOAD
        @(posedge clk);             pc <= 32'hCAFED00D; enable <= 1;
        @(posedge clk);                                              mem_r_data <= 32'h00072603;
        // After read should have finished, disable and validate the outputs hold
        // is_next_instruction_load should now be 1
        @(posedge clk);                                 enable <= 0; mem_r_data <= 32'hXXXXXXXX;
        @(posedge clk);
        @(posedge clk);

        // Try again with an unknown instruction and confirm it's "stuck" (never complete)
        @(posedge clk);             pc <= 32'hDEADBEEF; enable <= 1;
        @(posedge clk);                                              mem_r_data <= 32'h00000000;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);                                 enable <= 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        // Reset and provide the same inputs as the first phase; confirm it still works
        @(posedge clk); reset <= 1;
        @(posedge clk); reset <= 0;
        // Confirm it does nothing
        @(posedge clk);
        @(posedge clk);

        // Try normal operation with an ADD (not LOAD)
        @(posedge clk);             pc <= 32'hDEADBEEF; enable <= 1;
        @(posedge clk);                                              mem_r_data <= 32'hfff78793;
        @(posedge clk);
        @(posedge clk);

        $finish;
    end
endmodule;