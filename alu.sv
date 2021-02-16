module alu(
    input alu_op_t operation,
    input logic [XLEN-1:0] operand_1,
    input logic [XLEN-1:0] operand_2,
    output logic [XLEN-1:0] result,
    output logic result_nonzero
);

    assign result_nonzero = result != 0;

    always_comb begin
        case (operation)
            // Used to propagate unexpected opcodes
            ALU_INVALID: result = 'x;

            ALU_ADD: result = operand_1 + operand_2;
            ALU_SUB: result = operand_1 - operand_2;
            ALU_XOR: result = operand_1 ^ operand_2;
            ALU_OR:  result = operand_1 | operand_2;
            ALU_AND: result = operand_1 & operand_2;

            ALU_SHIFT_LEFT:             result = operand_1 << operand_2;
            ALU_SHIFT_RIGHT_LOGICAL:    result = operand_1 >> operand_2; 
            ALU_SHIFT_RIGHT_ARITHMETIC: result = signed'(operand_1) >>> operand_2;

            ALU_COMPARE_EQUAL:                     result = operand_1 == operand_2 ? 1 : 0;
            ALU_COMPARE_NOT_EQUAL:                 result = operand_1 != operand_2 ? 1 : 0;
            ALU_COMPARE_LESS_SIGNED:               result = signed'(operand_1) < signed'(operand_2) ? 1 : 0;
            ALU_COMPARE_LESS_UNSIGNED:             result = operand_1 < operand_2 ? 1 : 0;
            ALU_COMPARE_GREATER_OR_EQUAL_SIGNED:   result = signed'(operand_1) >= signed'(operand_2) ? 1 : 0;
            ALU_COMPARE_GREATER_OR_EQUAL_UNSIGNED: result = operand_1 >= operand_2 ? 1 : 0;

            default: result = 32'hxxxxxxxx;
        endcase
    end

endmodule