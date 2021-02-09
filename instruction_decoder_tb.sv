`timescale 1ns/1ps
`include "isa_constants.sv"

module instruction_decoder_tb();
    initial begin
        $dumpfile("instruction_decoder_tb.vcd");
        $dumpvars(0,instruction_decoder_tb);
    end
    logic [ILEN-1:0] instr_bits;
    decoded_instruction_t decoded_instruction;

    opcode_t opcode;
    rv_reg_t rs1, rs2, rd;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [XLEN-1:0] i_imm_input, s_imm_input, u_imm_input, j_imm_input, b_imm_input;

    assign opcode = decoded_instruction.opcode;
    assign rs1 = decoded_instruction.rs1;
    assign rs2 = decoded_instruction.rs2;
    assign rd = decoded_instruction.rd;

    instruction_decoder dut (instr_bits, decoded_instruction);

    localparam delay = 10;

    initial begin
        // 010cc783 lbu a5,16(s9)
        // LOAD, I-type, rs1 25, rd 15, funct3 100, immediate 16
        instr_bits <= 32'h010cc783; #delay;
        // 02912a23 sw s1,52(sp)
        // STORE, S-type, rs1 2, rs2 9, immediate 52
        instr_bits <= 32'h02912a23; #delay;
        // fc010113 addi sp,sp,-64
        // OP_IMM, I-type, rs1 2, rd 2, funct3 000, immediate -64
        instr_bits <= 32'hfc010113; #delay;
        // 84: fed79ce3 bne a5,a3,7c
        // BRANCH, B-type, rs1 15, rs2 13, funct3 001, immediate -8
        instr_bits <= 32'hfed79ce3; #delay;
        // 00001717 auipc a4,0x1
        // AUIPC, U-type, rd 14, immediate 0x1000
        instr_bits <= 32'h00001717; #delay;
        // 00001cb7 lui s9,0x1
        // LUI, U-type, rd 25, immediate 0x1000
        instr_bits <= 32'h00001cb7; #delay;
    end
endmodule
