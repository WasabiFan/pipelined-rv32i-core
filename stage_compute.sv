`include "isa_constants.sv"
`include "isa_types.sv"

module stage_compute (
    input logic clock,
    input logic reset,
    input logic enable,
    input logic [XLEN-1:0] reg_rs1_val,
    input logic [XLEN-1:0] reg_rs2_val,
    input logic [XLEN-1:0] pc,
    input decoded_instruction_t curr_instr,
    output logic [XLEN-1:0] result,
    output compute_mem_control_t control_mem,
    output compute_reg_control_t control_rd_out,
    output jump_control_t control_jump_target
);

    logic [XLEN-1:0] next_result;
    compute_mem_control_t next_control_mem;
    compute_reg_control_t next_control_rd_out;
    jump_control_t next_control_jump_target;

    instruction_compute compute (
        .reg_rs1_val            (reg_rs1_val),
        .reg_rs2_val            (reg_rs2_val),
        .pc                     (pc),
        .curr_instr             (curr_instr),
        .result                 (next_result),
        .control_mem            (next_control_mem),
        .control_rd_out         (next_control_rd_out),
        .control_jump_target    (next_control_jump_target)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            control_rd_out.enable      <= 1'b0;
            control_mem.w_enable       <= 1'b0;
            control_jump_target.enable <= 1'b0;

            control_rd_out.which_register <= 'x;
            control_rd_out.source         <= REG_WRITE_FROM_COMPUTE;

            control_mem.width         <= WIDTH_WORD; // don't care
            control_mem.r_sign_extend <= 1'bx;
            control_mem.w_value       <= 'x;

            control_jump_target.target_addr <= 'x;

            result <= 'x;
        end else if (enable) begin
            control_rd_out           <= next_control_rd_out;
            control_mem              <= next_control_mem;
            control_jump_target      <= next_control_jump_target;
            result                   <= next_result;
        end else begin
            control_rd_out           <= control_rd_out;
            control_mem              <= control_mem;
            control_jump_target      <= control_jump_target;
            result                   <= result;
        end
    end
endmodule;
