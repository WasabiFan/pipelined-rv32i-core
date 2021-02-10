`timescale 1ns/1ps

module stage_memory_load_tb();
    initial begin
        $dumpfile("stage_memory_load_tb.vcd");
        $dumpvars(0,stage_memory_load_tb);
    end

    logic clk, reset;
    logic enable;
    logic [XLEN-1:0] instr_addr;
    logic [XLEN-1:0] mem_r_data;

    logic [XLEN-1:0] mem_addr;
    logic is_complete;
    logic [XLEN-1:0] loaded_value;

    stage_memory_load dut (clk, reset, enable, instr_addr, mem_r_data, is_complete, mem_addr, loaded_value);

    // Set up the clock
    parameter CLOCK_PERIOD=100;
    initial begin
        clk <= 0;
        forever #(CLOCK_PERIOD/2) clk <= ~clk;
    end

    initial begin
        @(posedge clk); reset <= 1;                             enable <= 0;
        @(posedge clk); reset <= 0; instr_addr <= 32'hCAFEBABE;              mem_r_data <= 32'h00000000;
        // Confirm it does nothing
        @(posedge clk);
        @(posedge clk);

        // Enable and read a value
        @(posedge clk);             instr_addr <= 32'hDEADBEEF; enable <= 1;
        @(posedge clk);                                                      mem_r_data <= 32'hAB12CD34;
        // After read should have finished, disable and validate the outputs hold
        @(posedge clk);                                         enable <= 0; mem_r_data <= 32'hXXXXXXXX;
        @(posedge clk);
        @(posedge clk);

        // Perform another read
        @(posedge clk);             instr_addr <= 32'hCAFED00D; enable <= 1;
        @(posedge clk);                                                      mem_r_data <= 32'hEF56AB78;
        // After read should have finished, disable and validate the outputs hold
        @(posedge clk);                                         enable <= 0; mem_r_data <= 32'hXXXXXXXX;
        @(posedge clk);
        @(posedge clk);

        $finish;
    end
endmodule;