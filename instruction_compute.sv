`include "isa_constants.sv"
`include "isa_types.sv"

module instruction_compute (
    input logic [XLEN-1:0] reg_rs1_val,
    input logic [XLEN-1:0] reg_rs2_val,
    input logic [XLEN-1:0] mem_load_val,
    input logic [XLEN-1:0] pc,
    input decoded_instruction_t curr_instr,
    output enableable_word_t control_store,
    output enableable_word_t control_rd_out,
    output enableable_word_t control_jump_target_addr
);

    logic [XLEN-1:0] i_effective_addr;
    assign i_effective_addr = curr_instr.i_imm_input + reg_rs1_val;

    logic [4:0] shamnt;
    assign shamnt = curr_instr.i_imm_input[4:0];
    logic shift_type;
    assign shift_type = curr_instr.i_imm_input[10];

    always_comb begin
        control_rd_out.value           = 'x;
        control_store.value            = 'x;
        control_jump_target_addr.value = 'x;

        control_rd_out.enable           = 1'b0;
        control_store.enable            = 1'b0;
        control_jump_target_addr.enable = 1'b0;

        case (curr_instr.opcode)
            OPCODE_OP_IMM: begin
                control_rd_out.enable = 1'b1;
                case (curr_instr.funct3)
                    `FUNCT3_ADDI:  control_rd_out.value = reg_rs1_val + curr_instr.i_imm_input;
                    `FUNCT3_SLTI:  control_rd_out.value = signed'(reg_rs1_val) < signed'(curr_instr.i_imm_input);
                    `FUNCT3_SLTIU: control_rd_out.value = reg_rs1_val < curr_instr.i_imm_input;
                    `FUNCT3_XORI:  control_rd_out.value = reg_rs1_val ^ curr_instr.i_imm_input;
                    `FUNCT3_ORI:   control_rd_out.value = reg_rs1_val | curr_instr.i_imm_input;
                    `FUNCT3_ANDI:  control_rd_out.value = reg_rs1_val & curr_instr.i_imm_input;
                    `FUNCT3_SLLI:  control_rd_out.value = reg_rs1_val << shamnt;
                    `FUNCT3_SRLI_SRAI:
                        if (shift_type) control_rd_out.value = signed'(reg_rs1_val ) >>> curr_instr.i_imm_input;
                        else            control_rd_out.value = reg_rs1_val >> curr_instr.i_imm_input;
                    default:       control_rd_out.value = 'hx;
                endcase
            end

            OPCODE_OP: begin
                control_rd_out.enable = 1'b1;
                case (curr_instr.funct3)
                    `FUNCT3_ADD_SUB: case (curr_instr.funct7)
                        `FUNCT7_ADD: control_rd_out.value = reg_rs1_val + reg_rs2_val;
                        `FUNCT7_SUB: control_rd_out.value = reg_rs1_val - reg_rs2_val;
                        default:     control_rd_out.value = 'X;
                    endcase
                    `FUNCT3_SLL:    control_rd_out.value = reg_rs1_val << reg_rs2_val[4:0];
                    `FUNCT3_SLT:    control_rd_out.value = signed'(reg_rs1_val) < signed'(reg_rs2_val);
                    `FUNCT3_SLTU:   control_rd_out.value = reg_rs1_val < reg_rs2_val;
                    `FUNCT3_XOR:    control_rd_out.value = reg_rs1_val ^ reg_rs2_val;
                    `FUNCT3_OR:     control_rd_out.value = reg_rs1_val | reg_rs2_val;
                    `FUNCT3_AND:    control_rd_out.value = reg_rs1_val & reg_rs2_val;
                    default: control_rd_out.value = 'X;
                endcase
            end

            OPCODE_JAL: begin
                control_rd_out.enable = 1'b1;
                control_jump_target_addr.enable = 1'b1;

                control_rd_out.value = pc + 4;
                control_jump_target_addr.value = pc + curr_instr.j_imm_input;
            end

            OPCODE_JALR: begin
                control_rd_out.enable = 1'b1;
                control_jump_target_addr.enable = 1'b1;

                control_rd_out.value = pc + 4;
                control_jump_target_addr.value = { i_effective_addr[31:1], 1'b0 };
            end

            OPCODE_BRANCH: begin
                case (curr_instr.funct3)
                    `FUNCT3_BEQ:  control_jump_target_addr.enable = reg_rs1_val == reg_rs2_val;
                    `FUNCT3_BNE:  control_jump_target_addr.enable = reg_rs1_val != reg_rs2_val;
                    `FUNCT3_BLT:  control_jump_target_addr.enable = signed'(reg_rs1_val) <  signed'(reg_rs2_val);
                    `FUNCT3_BLTU: control_jump_target_addr.enable =         reg_rs1_val  <          reg_rs2_val;
                    `FUNCT3_BGE:  control_jump_target_addr.enable = signed'(reg_rs1_val) >= signed'(reg_rs2_val);
                    `FUNCT3_BGEU: control_jump_target_addr.enable =         reg_rs1_val  >=         reg_rs2_val;
                    default:      control_jump_target_addr.enable = 1'b0;
                endcase
                control_jump_target_addr.value = pc + curr_instr.b_imm_input;
            end

            OPCODE_LUI: begin
                control_rd_out.enable = 1'b1;
                control_rd_out.value = curr_instr.u_imm_input;
            end

            OPCODE_AUIPC: begin
                control_rd_out.enable = 1'b1;
                control_rd_out.value = pc + curr_instr.u_imm_input;
            end

            OPCODE_LOAD: begin
                control_rd_out.enable = 1'b1;
                case (curr_instr.funct3)
                    `FUNCT3_LB:  control_rd_out.value = `SIGEXT( mem_load_val, 8,  XLEN);
                    `FUNCT3_LBU: control_rd_out.value =   `ZEXT( mem_load_val, 8,  XLEN);
                    `FUNCT3_LH:  control_rd_out.value = `SIGEXT( mem_load_val, 16, XLEN);
                    `FUNCT3_LHU: control_rd_out.value =   `ZEXT( mem_load_val, 16, XLEN);
                    `FUNCT3_LW:  control_rd_out.value =          mem_load_val;
                    default:     control_rd_out.value = 'X;
                endcase
            end

            OPCODE_STORE: begin
                control_store.enable = 1'b1;
                control_store.value = reg_rs2_val;
            end

            OPCODE_UNKNOWN: begin /* Do nothing */ end
        endcase
    end
endmodule