typedef enum {
    STAGE_INSTRUCTION_FETCH,
    STAGE_REGISTER_READ,
    STAGE_COMPUTE,
    STAGE_MEMORY_TRANSACTION,
    STAGE_WRITEBACK
} stage_t;

module hart(
    input logic clock,
    input logic reset,
    input logic [XLEN-1:0] memory_mapped_io_r_data,
    input logic memory_mapped_io_write_complete,
    output mem_write_control_t memory_mapped_io_control
);
    parameter reset_vector   = 32'h00010000;
    parameter ram_start_addr = 32'h00020000;

    stage_t current_stage;

    logic [XLEN-1:0] data_memory_addr, data_memory_w_data, data_memory_r_data;
    mem_width_t data_memory_width;
    logic data_memory_w_enable, data_memory_r_sign_extend;
    memory #(.ram_start_addr(ram_start_addr)) data_memory (
        .clock                       (clock),
        .addr                        (data_memory_addr),
        .r_width                     (data_memory_width),
        .r_sign_extend               (data_memory_r_sign_extend),
        .w_data                      (data_memory_w_data),
        .w_width                     (data_memory_width),
        .w_enable                    (data_memory_w_enable),
        .memory_mapped_io_r_data     (memory_mapped_io_r_data),
        .r_data                      (data_memory_r_data),
        .memory_mapped_io_control    (memory_mapped_io_control)
    );

    logic [XLEN-1:0] instruction_memory_addr, instruction_memory_r_data;
    rom instruction_memory (
        .clock  (clock),
        // ROM is mapped starting at the reset vector
        .addr   (instruction_memory_addr - reset_vector),
        .r_data (instruction_memory_r_data)
    );

    // STAGE 1: INSTRUCTION FETCH
    logic [ILEN-1:0] instruction_bits;
    assign instruction_memory_addr = pc;
    assign instruction_bits = instruction_memory_r_data;

    decoded_instruction_t current_instruction;
    instruction_decoder instruction_decoder (
        .instr_bits             (instruction_bits),
        .decoded_instruction    (current_instruction)
    );

    // STAGE 2: REGISTER LOAD
    logic [XLEN-1:0] pc;
    reg_write_control_t register_write_control;
    logic [XLEN-1:0] register_rs1_val, register_rs2_val;
    register_file regfile (
        .clock            (clock),
        .reset            (reset),
        .rs1              (current_instruction.rs1),
        .rs2              (current_instruction.rs2),
        .write_control    (register_write_control),
        .rs1_val          (register_rs1_val),
        .rs2_val          (register_rs2_val)
    );

    // STAGE 3: COMPUTE
    logic [XLEN-1:0] compute_result;
    compute_mem_control_t control_mem;
    compute_reg_control_t control_reg_write;
    jump_control_t control_jump_target;
    stage_compute compute (
        .clock                  (clock),
        .reset                  (reset),
        .enable                 (current_stage == STAGE_COMPUTE),
        .reg_rs1_val            (register_rs1_val),
        .reg_rs2_val            (register_rs2_val),
        .pc                     (pc),
        .curr_instr             (current_instruction),
        .result                 (compute_result),
        .control_mem            (control_mem),
        .control_rd_out         (control_reg_write),
        .control_jump_target    (control_jump_target)
    );

    // STAGE 4: MEMORY TRANSACTION
    assign data_memory_w_enable      = control_mem.w_enable && current_stage == STAGE_MEMORY_TRANSACTION;
    assign data_memory_addr          = current_stage == STAGE_MEMORY_TRANSACTION ? compute_result : 'x;
    assign data_memory_width         = control_mem.width;
    assign data_memory_r_sign_extend = control_mem.r_sign_extend;
    assign data_memory_w_data        = control_mem.w_value;

    // STAGE 5: WRITEBACK
    always_comb begin
        register_write_control.which_register = control_reg_write.which_register;
        register_write_control.enable         = control_reg_write.enable && current_stage == STAGE_WRITEBACK;
        case (control_reg_write.source)
            REG_WRITE_FROM_COMPUTE: register_write_control.value = compute_result;
            REG_WRITE_FROM_MEMORY:  register_write_control.value = data_memory_r_data;
            default:                register_write_control.value = 'x;
        endcase
    end

    // Control flow
    always_ff @(posedge clock) begin
        if (reset) pc <= reset_vector;
        else if (current_stage == STAGE_WRITEBACK) begin
            if (control_jump_target.enable) pc <= control_jump_target.target_addr;
            else                            pc <= pc + 4;
        end else pc <= pc;
    end

    // Stage progression logic
    logic current_stage_is_complete;
    stage_t next_stage;
    always_comb begin
        case (current_stage)
            STAGE_INSTRUCTION_FETCH: begin
                current_stage_is_complete = 1'b1;
                next_stage = STAGE_REGISTER_READ;
            end
            STAGE_REGISTER_READ: begin
                current_stage_is_complete = 1'b1;
                next_stage = STAGE_COMPUTE;
            end
            STAGE_COMPUTE: begin
                current_stage_is_complete = 1'b1;
                next_stage = STAGE_MEMORY_TRANSACTION;
            end
            STAGE_MEMORY_TRANSACTION: begin
                current_stage_is_complete = !memory_mapped_io_control.enable || (memory_mapped_io_control.enable && memory_mapped_io_write_complete);
                next_stage = STAGE_WRITEBACK;
            end
            STAGE_WRITEBACK: begin
                current_stage_is_complete = 1'b1;
                next_stage = STAGE_INSTRUCTION_FETCH;
            end
            default: begin
                // Shouldn't happen
                current_stage_is_complete = 1'b0;
                next_stage = STAGE_INSTRUCTION_FETCH;
            end
        endcase
    end

    // Top-level stage control
    always_ff @(posedge clock) begin
        if (reset) current_stage <= STAGE_INSTRUCTION_FETCH;
        else begin
            if (current_stage_is_complete) current_stage <= next_stage;
            else                           current_stage <= current_stage;
        end
    end
endmodule;
