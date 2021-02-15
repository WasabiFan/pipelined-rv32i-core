typedef enum {
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
    ALU_COMPARE_GREATER_OR_EQUAL_UNSIGNED,
} alu_op_t;

module alu(
    input alu_op_t operation,
    input logic [XLEN-1:0] operand_1,
    input logic [XLEN-1:0] operand_2,
    output logic [XLEN-1:0] result,
    output logic result_nonzero
);

    assign result_nonzero = result != 0;

    always_comb begin
        case (operation) begin
            ALU_ADD: result = operand_1 + operand_2;
            ALU_SUB: result = operand_1 - operand_2;
            ALU_XOR: result = operand_1 ^ operand_2;
            ALU_OR:  result = operand_1 | operand_2;
            ALU_AND: result = operand_1 & operand_2;

            ALU_SHIFT_LEFT:             result = operand_1 << operand_2;
            ALU_SHIFT_RIGHT_LOGICAL:    result = operand_1 >> operand_2; 
            ALU_SHIFT_RIGHT_ARITHMETIC: result = signed'(operand_1) >>> operand_2;

            ALU_COMPARE_EQUAL:                     result = operand_1 == operand_2;
            ALU_COMPARE_NOT_EQUAL:                 result = operand_1 != operand_2;
            ALU_COMPARE_LESS_SIGNED:               result = signed'(operand_1) < signed'(operand_2);
            ALU_COMPARE_LESS_UNSIGNED:             result = operand_1 < operand_2;
            ALU_COMPARE_GREATER_OR_EQUAL_SIGNED:   result = signed'(operand_1) >= signed'(operand_2);
            ALU_COMPARE_GREATER_OR_EQUAL_UNSIGNED: result = operand_1 >= operand_2;

            default: result = 32'hxxxxxxxx;
        end
    end

endmodule