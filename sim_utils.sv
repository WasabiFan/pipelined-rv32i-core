`define DECODED_INSTRUCTION_DEBUG_EXPANSION(instr, name) \
generate \
begin : name \
opcode_t opcode = instr.opcode;\
rv_reg_t rs1 = instr.rs1;\
rv_reg_t rs2 = instr.rs2;\
rv_reg_t rd = instr.rd;\
logic [2:0] funct3 = instr.funct3;\
logic [6:0] funct7 = instr.funct7;\
logic [XLEN-1:0] i_imm_input = instr.i_imm_input;\
logic [XLEN-1:0] s_imm_input = instr.s_imm_input;\
logic [XLEN-1:0] u_imm_input = instr.u_imm_input;\
logic [XLEN-1:0] j_imm_input = instr.j_imm_input;\
logic [XLEN-1:0] b_imm_input = instr.b_imm_input;\
end \
endgenerate
