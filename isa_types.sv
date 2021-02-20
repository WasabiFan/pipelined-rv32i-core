`include "isa_constants.sv"

`ifndef ISA_TYPES_SV
`define ISA_TYPES_SV

typedef enum {
    WIDTH_BYTE,
    WIDTH_HALFWORD,
    WIDTH_WORD
} mem_width_t;

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

typedef enum {
    ALU_INVALID,
    ALU_ADD,
    ALU_SUB,
    ALU_XOR,
    ALU_OR,
    ALU_AND,
    ALU_SHIFT_LEFT,
    ALU_SHIFT_RIGHT_LOGICAL,
    ALU_SHIFT_RIGHT_ARITHMETIC,
    // equality/inequality comparison could logically be done via subtraction,
    // but explicit options are clearer.
    ALU_COMPARE_EQUAL,
    ALU_COMPARE_NOT_EQUAL,
    ALU_COMPARE_LESS_SIGNED,
    ALU_COMPARE_LESS_UNSIGNED,
    ALU_COMPARE_GREATER_OR_EQUAL_SIGNED,
    ALU_COMPARE_GREATER_OR_EQUAL_UNSIGNED
} alu_op_t;

typedef struct packed {
    opcode_t opcode;
    rv_reg_t rs1, rs2, rd;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [XLEN-1:0] i_imm_input, s_imm_input, u_imm_input, j_imm_input, b_imm_input;
} decoded_instruction_t;

typedef struct packed {
    logic [XLEN-1:0] target_addr;
    logic enable;
} jump_control_t;

typedef struct packed {
    logic [XLEN-1:0] addr;
    logic [XLEN-1:0] value;
    mem_width_t width;
    logic enable;
} mem_write_control_t;

typedef struct packed {
    rv_reg_t which_register;
    logic [XLEN-1:0] value;
    logic enable;
} reg_write_control_t;

`endif
