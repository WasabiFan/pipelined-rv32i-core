`include "isa_constants.sv"
`include "isa_types.sv"

typedef struct packed {
    mem_width_t width;
    logic r_sign_extend;
    logic w_enable;
    logic [XLEN-1:0] w_value;
} compute_mem_control_t;

typedef enum logic {
    REG_WRITE_FROM_COMPUTE,
    REG_WRITE_FROM_MEMORY
} red_write_source_t;

typedef struct packed {
    rv_reg_t which_register;
    logic enable;
    red_write_source_t source;
} compute_reg_control_t;

module instruction_compute (
    input logic [XLEN-1:0] reg_rs1_val,
    input logic [XLEN-1:0] reg_rs2_val,
    input logic [XLEN-1:0] pc,
    input decoded_instruction_t curr_instr,
    output logic [XLEN-1:0] result,
    output compute_mem_control_t control_mem,
    output compute_reg_control_t control_rd_out,
    output jump_control_t control_jump_target
);

    logic [XLEN-1:0] i_effective_addr;
    assign i_effective_addr = curr_instr.i_imm_input + reg_rs1_val;

    // TODO: why'd I get these from the immediate rather than funct7? Seems silly.
    logic shift_type;
    assign shift_type = curr_instr.i_imm_input[10];

    alu_op_t alu_operation;
    logic [XLEN-1:0] alu_operand_1, alu_operand_2;
    logic [XLEN-1:0] alu_result;
    logic alu_result_nonzero;
    alu alu (
        .operation         (alu_operation),
        .operand_1         (alu_operand_1),
        .operand_2         (alu_operand_2),
        .result            (alu_result),
        .result_nonzero    (alu_result_nonzero)
    );

    assign result = alu_result;

    always_comb begin
        control_rd_out.enable      = 1'b0;
        control_mem.w_enable       = 1'b0;
        control_jump_target.enable = 1'b0;

        control_rd_out.which_register = 'x;
        control_rd_out.source         = REG_WRITE_FROM_COMPUTE;

        control_mem.width = WIDTH_WORD; // don't care
        control_mem.r_sign_extend = 1'bx;
        control_mem.w_value = 'x;

        control_jump_target.target_addr = 'x;

        alu_operand_1 = 'x;
        alu_operand_2 = 'x;
        alu_operation = ALU_INVALID;

        case (curr_instr.opcode)
            OPCODE_OP_IMM: begin
                control_rd_out.enable = 1'b1;
                control_rd_out.which_register = curr_instr.rd;
                control_rd_out.source = REG_WRITE_FROM_COMPUTE;

                alu_operand_1 = reg_rs1_val;
                alu_operand_2 = curr_instr.i_imm_input;

                case (curr_instr.funct3)
                    `FUNCT3_ADDI:  alu_operation = ALU_ADD;
                    `FUNCT3_SLTI:  alu_operation = ALU_COMPARE_LESS_SIGNED;
                    `FUNCT3_SLTIU: alu_operation = ALU_COMPARE_LESS_UNSIGNED;
                    `FUNCT3_XORI:  alu_operation = ALU_XOR;
                    `FUNCT3_ORI:   alu_operation = ALU_OR;
                    `FUNCT3_ANDI:  alu_operation = ALU_AND;
                    `FUNCT3_SLLI:  alu_operation = ALU_SHIFT_LEFT;
                    `FUNCT3_SRLI_SRAI:
                        if (shift_type) alu_operation = ALU_SHIFT_RIGHT_ARITHMETIC;
                        else            alu_operation = ALU_SHIFT_RIGHT_LOGICAL;
                    default:       alu_operation = ALU_INVALID;
                endcase
            end

            OPCODE_OP: begin
                control_rd_out.enable   = 1'b1;
                control_rd_out.which_register = curr_instr.rd;
                control_rd_out.source = REG_WRITE_FROM_COMPUTE;

                alu_operand_1 = reg_rs1_val;
                alu_operand_2 = reg_rs2_val;

                case (curr_instr.funct3)
                    `FUNCT3_ADD_SUB: case (curr_instr.funct7)
                        `FUNCT7_ADD: alu_operation = ALU_ADD;
                        `FUNCT7_SUB: alu_operation = ALU_SUB;
                        default:     alu_operation = ALU_ADD;
                    endcase
                    `FUNCT3_SLT:    alu_operation = ALU_COMPARE_LESS_SIGNED;
                    `FUNCT3_SLTU:   alu_operation = ALU_COMPARE_LESS_UNSIGNED;
                    `FUNCT3_XOR:    alu_operation = ALU_XOR;
                    `FUNCT3_OR:     alu_operation = ALU_OR;
                    `FUNCT3_AND:    alu_operation = ALU_AND;
                    `FUNCT3_SLL: begin
                                    alu_operation = ALU_SHIFT_LEFT; alu_operand_2 = { 27'b0, reg_rs2_val[4:0] };
                    end
                    `FUNCT3_SRL_SRA:
                        if (shift_type) alu_operation = ALU_SHIFT_RIGHT_ARITHMETIC;
                        else            alu_operation = ALU_SHIFT_RIGHT_LOGICAL;
                    default: alu_operation = ALU_INVALID;
                endcase
            end

            OPCODE_JAL: begin
                control_rd_out.enable = 1'b1;
                control_rd_out.which_register = curr_instr.rd;
                control_rd_out.source = REG_WRITE_FROM_COMPUTE;

                alu_operand_1 = pc;
                alu_operand_2 = 4;
                alu_operation = ALU_ADD;

                control_jump_target.enable = 1'b1;
                control_jump_target.target_addr = pc + curr_instr.j_imm_input;
            end

            OPCODE_JALR: begin
                control_rd_out.enable = 1'b1;
                control_rd_out.which_register = curr_instr.rd;
                control_rd_out.source = REG_WRITE_FROM_COMPUTE;

                alu_operand_1 = pc;
                alu_operand_2 = 4;
                alu_operation = ALU_ADD;

                control_jump_target.enable = 1'b1;
                control_jump_target.target_addr = { i_effective_addr[31:1], 1'b0 };
            end

            OPCODE_BRANCH: begin
                alu_operand_1 = reg_rs1_val;
                alu_operand_2 = reg_rs2_val;
                control_jump_target.enable = alu_result_nonzero;
                case (curr_instr.funct3)
                    `FUNCT3_BEQ:  alu_operation = ALU_COMPARE_EQUAL;
                    `FUNCT3_BNE:  alu_operation = ALU_COMPARE_NOT_EQUAL;
                    `FUNCT3_BLT:  alu_operation = ALU_COMPARE_LESS_SIGNED;
                    `FUNCT3_BLTU: alu_operation = ALU_COMPARE_LESS_UNSIGNED;
                    `FUNCT3_BGE:  alu_operation = ALU_COMPARE_GREATER_OR_EQUAL_SIGNED;
                    `FUNCT3_BGEU: alu_operation = ALU_COMPARE_GREATER_OR_EQUAL_UNSIGNED;
                    default:      alu_operation = ALU_INVALID;
                endcase
                control_jump_target.target_addr = pc + curr_instr.b_imm_input;
            end

            OPCODE_LUI: begin
                control_rd_out.enable = 1'b1;
                control_rd_out.which_register = curr_instr.rd;
                control_rd_out.source = REG_WRITE_FROM_COMPUTE;

                alu_operand_1 = '0;
                alu_operand_2 = curr_instr.u_imm_input;
                alu_operation = ALU_ADD;
            end

            OPCODE_AUIPC: begin
                control_rd_out.enable = 1'b1;
                control_rd_out.which_register = curr_instr.rd;
                control_rd_out.source = REG_WRITE_FROM_COMPUTE;

                alu_operand_1 = pc;
                alu_operand_2 = curr_instr.u_imm_input;
                alu_operation = ALU_ADD;
            end

            OPCODE_LOAD: begin
                control_rd_out.enable = 1'b1;
                control_rd_out.which_register = curr_instr.rd;
                control_rd_out.source = REG_WRITE_FROM_MEMORY;

                alu_operand_1 = curr_instr.i_imm_input;
                alu_operand_2 = reg_rs1_val;
                alu_operation = ALU_ADD;

                case (curr_instr.funct3)
                    `FUNCT3_LB:  begin control_mem.width = WIDTH_BYTE;     control_mem.r_sign_extend = 1'b1; end
                    `FUNCT3_LBU: begin control_mem.width = WIDTH_BYTE;     control_mem.r_sign_extend = 1'b0; end
                    `FUNCT3_LH:  begin control_mem.width = WIDTH_HALFWORD; control_mem.r_sign_extend = 1'b1; end
                    `FUNCT3_LHU: begin control_mem.width = WIDTH_HALFWORD; control_mem.r_sign_extend = 1'b0; end
                    `FUNCT3_LW:  begin control_mem.width = WIDTH_WORD;     control_mem.r_sign_extend = 1'b0; end
                    default:     begin control_mem.width = WIDTH_WORD;     control_mem.r_sign_extend = 1'b0; end // don't care
                endcase
            end

            OPCODE_STORE: begin
                control_mem.w_enable = 1'b1;
                control_mem.w_value = reg_rs2_val;

                alu_operand_1 = curr_instr.s_imm_input;
                alu_operand_2 = reg_rs1_val;
                alu_operation = ALU_ADD;

                case (curr_instr.funct3)
                    `FUNCT3_SB: control_mem.width = WIDTH_BYTE;
                    `FUNCT3_SH: control_mem.width = WIDTH_HALFWORD;
                    `FUNCT3_SW: control_mem.width = WIDTH_WORD;
                    default:    control_mem.width = WIDTH_WORD; // don't care
                endcase
            end

            OPCODE_UNKNOWN: begin /* Do nothing */ end
        endcase
    end
endmodule
