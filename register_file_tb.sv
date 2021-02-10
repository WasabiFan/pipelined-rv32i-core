`timescale 1ns/1ps

module register_file_tb();
    initial begin
        $dumpfile("register_file_tb.vcd");
        $dumpvars(0,register_file_tb);
    end

    logic clk, reset;
    rv_reg_t rs1;
    rv_reg_t rs2;
    reg_write_control_t write_control;

    rv_reg_t w_which_register;
    logic [XLEN-1:0] w_value;
    logic w_enable;

    assign w_which_register = write_control.which_register;
    assign w_value = write_control.value;
    assign w_enable = write_control.enable;

    logic [XLEN-1:0] rs1_val;
    logic [XLEN-1:0] rs2_val;

    register_file dut (
        .clock            (clk),
        .reset            (reset),
        .rs1              (rs1),
        .rs2              (rs2),
        .write_control    (write_control),
        .rs1_val          (rs1_val),
        .rs2_val          (rs2_val)
    );

    parameter CLOCK_PERIOD=100;
    initial begin
        clk <= 0;
        forever #(CLOCK_PERIOD/2) clk <= ~clk;
    end

    initial begin
        @(posedge clk); reset <= 1'b1;
        @(posedge clk); reset <= 1'b0;

        @(posedge clk); rs1 <= 0; rs2 <= 5; // both should be 0

        @(posedge clk); write_control.enable <= 1'b0; write_control.which_register <= 5; write_control.value <= 32'hCAFEBABE;
        @(posedge clk); write_control.enable <= 1'b1;
        @(posedge clk);
        @(posedge clk);

        $finish;
    end
endmodule;