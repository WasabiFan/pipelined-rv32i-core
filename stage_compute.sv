`include "isa_constants.sv"
`include "isa_types.sv"

module stage_compute (
    input logic clock,
    input logic reset,
    input logic enable,
    input logic [XLEN-1:0] reg_rs1_val,
    input logic [XLEN-1:0] reg_rs2_val,
    input logic [XLEN-1:0] mem_load_val,
    input logic [XLEN-1:0] pc,
    input decoded_instruction_t curr_instr,
    output logic is_complete,
    output mem_write_control_t control_store,
    output reg_write_control_t control_rd_out,
    output jump_control_t control_jump_target
);

    assign is_complete = enable;

    mem_write_control_t next_control_store;
    reg_write_control_t next_control_rd_out;
    jump_control_t next_control_jump_target;

    instruction_compute compute (
        .reg_rs1_val                 (reg_rs1_val),
        .reg_rs2_val                 (reg_rs2_val),
        .mem_load_val                (mem_load_val),
        .pc                          (pc),
        .curr_instr                  (curr_instr),
        .control_store               (next_control_store),
        .control_rd_out              (next_control_rd_out),
        .control_jump_target         (next_control_jump_target)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            control_rd_out.enable      <= 1'b0;
            control_store.enable       <= 1'b0;
            control_jump_target.enable <= 1'b0;

            control_rd_out.value    <= 'x;
            control_rd_out.which_register <= 'x;

            control_store.value <= 'x;
            control_store.width <= write_word; // don't care
            control_store.addr  <= 'x;

            control_jump_target.target_addr <= 'x;


        end else if (enable) begin
            control_rd_out           <= next_control_rd_out;
            control_store            <= next_control_store;
            control_jump_target      <= next_control_jump_target;
        end else begin
            control_rd_out           <= control_rd_out;
            control_store            <= control_store;
            control_jump_target      <= control_jump_target;
        end
    end
endmodule;
