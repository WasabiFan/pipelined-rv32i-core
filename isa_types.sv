`include "isa_constants.sv"

`ifndef ISA_TYPES_SV
`define ISA_TYPES_SV

typedef enum {
    write_byte,
    write_halfword,
    write_word
} write_width_t;

typedef logic [4:0] rv_reg_t;

typedef enum {
    OPCODE_UNKNOWN,
    OPCODE_LUI,
    OPCODE_AUIPC,
    OPCODE_JAL,
    OPCODE_JALR,
    OPCODE_OP_IMM,
    OPCODE_OP,
    OPCODE_BRANCH,
    OPCODE_LOAD,
    OPCODE_STORE
} opcode_t;

typedef struct packed {
    opcode_t opcode;
    rv_reg_t rs1, rs2, rd;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [XLEN-1:0] i_imm_input, s_imm_input, u_imm_input, j_imm_input, b_imm_input;
} decoded_instruction_t;

typedef struct packed {
    logic [XLEN-1:0] value;
    logic enable;
} enableable_word_t;

`endif
