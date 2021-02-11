`include "isa_constants.sv"
`include "isa_utils.sv"
`include "isa_types.sv"

function opcode_t extract_opcode;
    input logic [XLEN-1:0] instr_bits;
    opcode_t opcode;

    case (instr_bits[6:0])
        `OPCODE_LUI:    opcode = OPCODE_LUI;
        `OPCODE_AUIPC:  opcode = OPCODE_AUIPC;
        `OPCODE_JAL:    opcode = OPCODE_JAL;
        `OPCODE_JALR:   opcode = OPCODE_JALR;
        `OPCODE_OP_IMM: opcode = OPCODE_OP_IMM;
        `OPCODE_OP:     opcode = OPCODE_OP;
        `OPCODE_BRANCH: opcode = OPCODE_BRANCH;
        `OPCODE_LOAD:   opcode = OPCODE_LOAD;
        `OPCODE_STORE:  opcode = OPCODE_STORE;
        default:        opcode = OPCODE_UNKNOWN;
    endcase

    return opcode;
endfunction

module instruction_decoder (instr_bits, decoded_instruction);
    input logic [ILEN-1:0] instr_bits;
    output decoded_instruction_t decoded_instruction;

    assign decoded_instruction.opcode = extract_opcode(instr_bits);

    assign decoded_instruction.rd = instr_bits[11:7];
    assign decoded_instruction.rs1 = instr_bits[19:15];
    assign decoded_instruction.rs2 = instr_bits[24:20];

    assign decoded_instruction.funct3 = instr_bits[14:12];
    assign decoded_instruction.funct7 = instr_bits[31:25];

    logic [11:0] i_imm_raw, s_imm_raw;
    logic [12:0] b_imm_raw;
    logic [20:0] j_imm_raw;
    assign i_imm_raw = instr_bits[31:20];
    assign s_imm_raw = { instr_bits[31:25], instr_bits[11:7] };
    assign j_imm_raw = { instr_bits[31], instr_bits[19:12], instr_bits[20], instr_bits[30:25], instr_bits[24:21], 1'b0 };
    assign b_imm_raw = { instr_bits[31], instr_bits[7], instr_bits[30:25], instr_bits[11:8], 1'b0 };

    assign decoded_instruction.i_imm_input = `SIGEXT(i_imm_raw, 12, XLEN);
    assign decoded_instruction.s_imm_input = `SIGEXT(s_imm_raw, 12, XLEN);
    assign decoded_instruction.u_imm_input = { instr_bits[31:12], 12'b0 };
    assign decoded_instruction.j_imm_input = `SIGEXT(j_imm_raw, 20, XLEN);
    assign decoded_instruction.b_imm_input = `SIGEXT(b_imm_raw, 12, XLEN);
endmodule
