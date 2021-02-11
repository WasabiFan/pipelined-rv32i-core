typedef enum {
    STAGE_INSTRUCTION_FETCH,
    STAGE_MEMORY_LOAD,
    STAGE_COMPUTE,
    STAGE_MEMORY_STORE,
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
    parameter rom_init_file = "mem.hex";

    stage_t current_stage;

    logic [ILEN-1:0] instruction_bits;
    decoded_instruction_t current_instruction;

    instruction_decoder instruction_decoder (
        .instr_bits             (instruction_bits),
        .decoded_instruction    (current_instruction)
    );

    logic [XLEN-1:0] data_memory_addr, data_memory_w_data, data_memory_r_data;
    write_width_t data_memory_w_width;
    logic data_memory_w_enable;
    memory #(.ram_start_addr(ram_start_addr)) data_memory (
        .clock                       (clock),
        .addr                        (data_memory_addr),
        .w_data                      (data_memory_w_data),
        .w_width                     (data_memory_w_width),
        .w_enable                    (data_memory_w_enable),
        .memory_mapped_io_r_data     (memory_mapped_io_r_data),
        .r_data                      (data_memory_r_data),
        .memory_mapped_io_control    (memory_mapped_io_control)
    );

    logic [XLEN-1:0] instruction_memory_addr, instruction_memory_r_data;
    rom #(
        .init_file(rom_init_file)
    ) instruction_memory (
        .clock  (clock),
        // ROM is mapped starting at the reset vector
        .addr   (instruction_memory_addr - reset_vector),
        .r_data (instruction_memory_r_data)
    );

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

    logic instruction_fetch_is_complete;
    stage_instruction_fetch instruction_fetch (
        .clock          (clock),
        .reset          (reset),
        .enable         (current_stage == STAGE_INSTRUCTION_FETCH),
        .pc             (pc),
        .mem_r_data     (instruction_memory_r_data),
        .is_complete    (instruction_fetch_is_complete),
        .mem_addr       (instruction_memory_addr),
        .instr_bits     (instruction_bits)
    );

    // TODO: below computation is duplicated in instruction_compute
    logic [XLEN-1:0] current_instruction_i_effective_addr;
    assign current_instruction_i_effective_addr = current_instruction.i_imm_input + register_rs1_val;

    logic memory_load_is_complete;
    logic [XLEN-1:0] memory_load_data_addr, memory_load_loaded_value;
    stage_memory_load memory_load (
        .clock               (clock),
        .reset               (reset),
        .enable              (current_stage == STAGE_MEMORY_LOAD),
        .i_effective_addr    (current_instruction_i_effective_addr),
        .mem_r_data          (data_memory_r_data),
        .is_complete         (memory_load_is_complete),
        .mem_addr            (memory_load_data_addr),
        .loaded_value        (memory_load_loaded_value)
    );

    logic compute_is_complete;
    mem_write_control_t control_store;
    jump_control_t control_jump_target;
    stage_compute compute (
        .clock                  (clock),
        .reset                  (reset),
        .enable                 (current_stage == STAGE_COMPUTE),
        .reg_rs1_val            (register_rs1_val),
        .reg_rs2_val            (register_rs2_val),
        .mem_load_val           (memory_load_loaded_value),
        .pc                     (pc),
        .curr_instr             (current_instruction),
        .is_complete            (compute_is_complete),
        .control_store          (control_store),
        .control_rd_out         (register_write_control),
        .control_jump_target    (control_jump_target)
    );

    // Data memory controller (mux)
    always_comb begin
        data_memory_w_enable = 1'b0;
        data_memory_addr = 'x;
        data_memory_w_data = 'x;
        data_memory_w_width = write_word; // don't care

        case (current_stage)
            STAGE_MEMORY_LOAD: begin
                data_memory_addr = memory_load_data_addr;
            end
            STAGE_MEMORY_STORE: begin
                data_memory_addr = control_store.addr;
                data_memory_w_enable = control_store.enable;
                data_memory_w_data = control_store.value;
                data_memory_w_width = control_store.width;
            end
        endcase;
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
                current_stage_is_complete = instruction_fetch_is_complete;
                next_stage = STAGE_MEMORY_LOAD;
            end
            STAGE_MEMORY_LOAD:       begin
                current_stage_is_complete = memory_load_is_complete;
                next_stage = STAGE_COMPUTE;
            end
            STAGE_COMPUTE:           begin
                current_stage_is_complete = compute_is_complete;
                next_stage = STAGE_MEMORY_STORE;
            end
            STAGE_MEMORY_STORE:      begin
                current_stage_is_complete = 1'b1;
                next_stage = STAGE_WRITEBACK;
            end
            STAGE_WRITEBACK:         begin
                current_stage_is_complete = !memory_mapped_io_control.enable || (memory_mapped_io_control.enable && memory_mapped_io_write_complete);
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
