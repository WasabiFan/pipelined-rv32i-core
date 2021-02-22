`include "sim_utils.sv"

typedef struct packed {
    logic valid;
    logic [XLEN-1:0] pc;
} instruction_fetch_closure_t;

typedef struct packed {
    logic valid;
    logic [XLEN-1:0] pc;
} register_read_closure_t;

typedef struct packed {
    logic valid;
    logic [XLEN-1:0] pc;
    decoded_instruction_t current_instruction;
} compute_closure_t;

typedef struct packed {
    logic valid;
    `ifdef SIMULATION
    // pc is not technically required, but is preferable for debugging
    logic [XLEN-1:0] pc;
    `endif
    logic [XLEN-1:0] compute_result;
    compute_mem_control_t control_mem;
    compute_reg_control_t control_reg_write;
} memory_transaction_closure_t;

typedef struct packed {
    logic valid;
    `ifdef SIMULATION
    // pc is not technically required, but is preferable for debugging
    logic [XLEN-1:0] pc;
    `endif
    logic [XLEN-1:0] compute_result;
    compute_reg_control_t control_reg_write;
} writeback_closure_t;

module hart(
    input logic clock,
    input logic reset,
    input logic [XLEN-1:0] memory_mapped_io_r_data,
    input logic memory_mapped_io_write_complete,
    output mem_write_control_t memory_mapped_io_control
);
    parameter reset_vector   = 32'h00010000;
    parameter ram_start_addr = 32'h00020000;

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

    `ifdef SIMULATION
    logic [XLEN-1:0] dbg_memory_mapped_io_control_addr = memory_mapped_io_control.addr;
    logic [XLEN-1:0] dbg_memory_mapped_io_control_value = memory_mapped_io_control.value;
    mem_width_t dbg_memory_mapped_io_control_width = memory_mapped_io_control.width;
    logic dbg_memory_mapped_io_control_enable = memory_mapped_io_control.enable;
    `endif

    logic [XLEN-1:0] instruction_memory_addr, instruction_memory_r_data;
    rom instruction_memory (
        .clock  (clock),
        // ROM is mapped starting at the reset vector
        .addr   (instruction_memory_addr - reset_vector),
        .r_data (instruction_memory_r_data)
    );

    // Stall conditions
    logic frontend_is_stalled;
    logic backend_is_stalled;
    always_comb begin
        frontend_is_stalled = 1'b0;
        backend_is_stalled  = 1'b0;

        // Stall the frontend only if the compute stage is missing operands (data hazard)
        // This will stall for at most one cycle; the only hazard which can require a stall
        // is usage of the result of a memory load, which will take one cycle to resolve.
        if (stage_3_compute_closure.valid) begin
            if (!stage_3_compute_register_rs1_has_value || !stage_3_compute_register_rs2_has_value)
                frontend_is_stalled = 1'b1;
        end

        // Stall if an mmio write is still in-progress
        if (memory_mapped_io_control.enable) begin
            if (!memory_mapped_io_write_complete) begin
                // If we're stalling a later stage, we must stall the earlier ones too
                frontend_is_stalled = 1'b1;
                backend_is_stalled  = 1'b1;
            end
        end
    end

    // PC gen + control flow
    // Note: depends on stage 3 (compute) result
    logic [XLEN-1:0] next_pc;
    logic is_jumping = !reset && stage_3_compute_closure.valid && stage_3_compute_control_jump_target.enable;
    always_comb begin
        if (frontend_is_stalled)
            next_pc = stage_1_instruction_fetch_closure.pc;
        else if (stage_3_compute_control_jump_target.enable)
            next_pc = stage_3_compute_control_jump_target.target_addr;
        else
            next_pc = stage_1_instruction_fetch_closure.pc + 4;
    end

    // =================================
    // STAGE 1: INSTRUCTION FETCH
    // =================================
    instruction_fetch_closure_t stage_1_instruction_fetch_closure;
    always_ff @(posedge clock) begin
        if (reset) begin
            stage_1_instruction_fetch_closure.pc    <= reset_vector;
            stage_1_instruction_fetch_closure.valid <= 1'b1;
        end else begin
            stage_1_instruction_fetch_closure.pc    <= next_pc;
            stage_1_instruction_fetch_closure.valid <= 1'b1;
        end
    end

    `ifdef SIMULATION
    logic [XLEN-1:0] dbg_stage_1_instruction_fetch_closure_pc = stage_1_instruction_fetch_closure.pc;
    logic dbg_stage_1_instruction_fetch_closure_valid         = stage_1_instruction_fetch_closure.valid;
    `endif

    assign instruction_memory_addr = stage_1_instruction_fetch_closure.pc;
    logic [ILEN-1:0] stage_1_instruction_fetch_instruction_bits;
    assign stage_1_instruction_fetch_instruction_bits = instruction_memory_r_data;

    // =================================
    // STAGE 2: REGISTER LOAD
    // =================================
    register_read_closure_t stage_2_register_read_closure;
    always_ff @(posedge clock) begin
        if (reset) begin
            stage_2_register_read_closure.valid               <= 1'b0;
            stage_2_register_read_closure.pc                  <= 'x;
        end else if (frontend_is_stalled) begin
            stage_2_register_read_closure.valid               <= stage_2_register_read_closure.valid;
            stage_2_register_read_closure.pc                  <= stage_2_register_read_closure.pc;
        end else begin
            stage_2_register_read_closure.valid               <= stage_1_instruction_fetch_closure.valid && !is_jumping;
            stage_2_register_read_closure.pc                  <= stage_1_instruction_fetch_closure.pc;
        end
    end

    // Memory reads are synchronous, so we can't capture the instruction bits as part of our closure
    // This "latch" is normally just a continuous assignment "output = input", but will retain the old
    // value if we stall.
    logic [XLEN-1:0] stage_2_register_read_instruction_bits;
    latch stage_2_register_read_instruction_bits_latch (
        .clock         (clock),
        .reset         (reset),
        .input_value   (stage_1_instruction_fetch_instruction_bits),
        .update        (!frontend_is_stalled),
        .output_value  (stage_2_register_read_instruction_bits)
    );

    `ifdef SIMULATION
    logic [XLEN-1:0] dbg_stage_2_register_read_closure_pc = stage_2_register_read_closure.pc;
    logic dbg_stage_2_register_read_closure_valid         = stage_2_register_read_closure.valid;

    `DECODED_INSTRUCTION_DEBUG_EXPANSION(stage_2_register_read_current_instruction, dbg_stage_2_register_read_current_instruction)
    `endif

    decoded_instruction_t stage_2_register_read_current_instruction;
    instruction_decoder instruction_decoder (
        .instr_bits             (stage_2_register_read_instruction_bits),
        .decoded_instruction    (stage_2_register_read_current_instruction)
    );

    reg_write_control_t register_write_control;
    logic [XLEN-1:0] stage_2_register_read_register_rs1_val, stage_2_register_read_register_rs2_val;
    register_file regfile (
        .clock            (clock),
        .reset            (reset),
        .rs1              (stage_2_register_read_current_instruction.rs1),
        .rs2              (stage_2_register_read_current_instruction.rs2),
        .write_control    (register_write_control),
        .rs1_val          (stage_2_register_read_register_rs1_val),
        .rs2_val          (stage_2_register_read_register_rs2_val)
    );
    `ifdef SIMULATION
    rv_reg_t dbg_register_write_control_which_register = register_write_control.which_register;
    logic [XLEN-1:0] dbg_register_write_control_value  = register_write_control.value;
    logic dbg_register_write_control_enable            = register_write_control.enable;
    `endif

    // =================================
    // STAGE 3: COMPUTE
    // =================================
    compute_closure_t stage_3_compute_closure;
    always_ff @(posedge clock) begin
        if (reset) begin
            stage_3_compute_closure.valid               <= 1'b0;
            stage_3_compute_closure.pc                  <= 'x;
            stage_3_compute_closure.current_instruction <= 'x;
        end else if (frontend_is_stalled) begin
            stage_3_compute_closure.valid               <= stage_3_compute_closure.valid;
            stage_3_compute_closure.pc                  <= stage_3_compute_closure.pc;
            stage_3_compute_closure.current_instruction <= stage_3_compute_closure.current_instruction;
        end else begin
            stage_3_compute_closure.valid               <= stage_2_register_read_closure.valid && !is_jumping && stage_2_register_read_current_instruction.opcode != OPCODE_UNKNOWN;
            stage_3_compute_closure.pc                  <= stage_2_register_read_closure.pc;
            stage_3_compute_closure.current_instruction <= stage_2_register_read_current_instruction;
        end
    end

    // Regfile reads are synchronous, so we can't capture the register values as part of our closure
    logic [XLEN-1:0] stage_3_compute_unforwarded_register_rs1_val;
    logic [XLEN-1:0] stage_3_compute_unforwarded_register_rs2_val;
    latch stage_3_compute_unforwarded_register_rs1_val_latch (
        .clock         (clock),
        .reset         (reset),
        .input_value   (stage_2_register_read_register_rs1_val),
        .update        (!frontend_is_stalled),
        .output_value  (stage_3_compute_unforwarded_register_rs1_val)
    );
    latch stage_3_compute_unforwarded_register_rs2_val_latch (
        .clock         (clock),
        .reset         (reset),
        .input_value   (stage_2_register_read_register_rs2_val),
        .update        (!frontend_is_stalled),
        .output_value  (stage_3_compute_unforwarded_register_rs2_val)
    );

    logic [XLEN-1:0] stage_3_compute_register_rs1_val;
    logic stage_3_compute_register_rs1_has_value;
    operand_forwarder rs1_forwarder (
        .rs                                             (stage_3_compute_closure.current_instruction.rs1),
        .rs_value                                       (stage_3_compute_unforwarded_register_rs1_val),
        .stage_4_memory_transaction_closure_valid       (stage_4_memory_transaction_closure.valid),
        .stage_4_memory_transaction_register_control    (stage_4_memory_transaction_closure.control_reg_write),
        .stage_4_memory_transaction_compute_result      (stage_4_memory_transaction_closure.compute_result),
        .stage_5_writeback_closure_valid                (stage_5_writeback_closure.valid),
        .stage_5_writeback_register_control             (stage_5_writeback_closure.control_reg_write),
        .stage_5_writeback_compute_result               (stage_5_writeback_closure.compute_result),
        .stage_5_writeback_memory_r_data                (stage_5_writeback_memory_r_data),
        .valid                                          (stage_3_compute_register_rs1_has_value),
        .operand_value                                  (stage_3_compute_register_rs1_val)
    );

    logic [XLEN-1:0] stage_3_compute_register_rs2_val;
    logic stage_3_compute_register_rs2_has_value;
    operand_forwarder rs2_forwarder (
        .rs                                             (stage_3_compute_closure.current_instruction.rs2),
        .rs_value                                       (stage_3_compute_unforwarded_register_rs2_val),
        .stage_4_memory_transaction_closure_valid       (stage_4_memory_transaction_closure.valid),
        .stage_4_memory_transaction_register_control    (stage_4_memory_transaction_closure.control_reg_write),
        .stage_4_memory_transaction_compute_result      (stage_4_memory_transaction_closure.compute_result),
        .stage_5_writeback_closure_valid                (stage_5_writeback_closure.valid),
        .stage_5_writeback_register_control             (stage_5_writeback_closure.control_reg_write),
        .stage_5_writeback_compute_result               (stage_5_writeback_closure.compute_result),
        .stage_5_writeback_memory_r_data                (stage_5_writeback_memory_r_data),
        .valid                                          (stage_3_compute_register_rs2_has_value),
        .operand_value                                  (stage_3_compute_register_rs2_val)
    );

    `ifdef SIMULATION
    logic [XLEN-1:0] dbg_stage_3_compute_closure_pc                       = stage_3_compute_closure.pc;
    logic dbg_stage_3_compute_closure_valid                               = stage_3_compute_closure.valid;
    decoded_instruction_t dbg_stage_3_compute_closure_current_instruction = stage_3_compute_closure.current_instruction;

    logic dbg_stage_3_compute_control_jump_target_enable          = stage_3_compute_control_jump_target.enable;
    logic [XLEN-1:0] dbg_stage_3_compute_control_jump_target_addr = stage_3_compute_control_jump_target.target_addr;
    `endif

    logic [XLEN-1:0] stage_3_compute_compute_result;
    compute_mem_control_t stage_3_compute_control_mem;
    compute_reg_control_t stage_3_compute_control_reg_write;
    jump_control_t stage_3_compute_control_jump_target;
    stage_compute compute (
        .enable                 (stage_3_compute_closure.valid),
        .reg_rs1_val            (stage_3_compute_register_rs1_val),
        .reg_rs2_val            (stage_3_compute_register_rs2_val),
        .pc                     (stage_3_compute_closure.pc),
        .curr_instr             (stage_3_compute_closure.current_instruction),
        .result                 (stage_3_compute_compute_result),
        .control_mem            (stage_3_compute_control_mem),
        .control_rd_out         (stage_3_compute_control_reg_write),
        .control_jump_target    (stage_3_compute_control_jump_target)
    );

    // =================================
    // STAGE 4: MEMORY TRANSACTION
    // =================================
    memory_transaction_closure_t stage_4_memory_transaction_closure;
    always_ff @(posedge clock) begin
        if (reset || (frontend_is_stalled && !backend_is_stalled)) begin
            stage_4_memory_transaction_closure.valid               <= 1'b0;
            `ifdef SIMULATION
            stage_4_memory_transaction_closure.pc                  <= 'x;
            `endif
            stage_4_memory_transaction_closure.compute_result      <= 'x;
            stage_4_memory_transaction_closure.control_mem         <= 'x;
            stage_4_memory_transaction_closure.control_reg_write   <= 'x;
        end else if (backend_is_stalled) begin
            stage_4_memory_transaction_closure.valid               <= stage_4_memory_transaction_closure.valid;
            `ifdef SIMULATION
            stage_4_memory_transaction_closure.pc                  <= stage_4_memory_transaction_closure.pc;
            `endif
            stage_4_memory_transaction_closure.compute_result      <= stage_4_memory_transaction_closure.compute_result;
            stage_4_memory_transaction_closure.control_mem         <= stage_4_memory_transaction_closure.control_mem;
            stage_4_memory_transaction_closure.control_reg_write   <= stage_4_memory_transaction_closure.control_reg_write;
        end else begin
            stage_4_memory_transaction_closure.valid               <= stage_3_compute_closure.valid;
            `ifdef SIMULATION
            stage_4_memory_transaction_closure.pc                  <= stage_3_compute_closure.pc;
            `endif
            stage_4_memory_transaction_closure.compute_result      <= stage_3_compute_compute_result;
            stage_4_memory_transaction_closure.control_mem         <= stage_3_compute_control_mem;
            stage_4_memory_transaction_closure.control_reg_write   <= stage_3_compute_control_reg_write;
        end
    end

    `ifdef SIMULATION
    logic [XLEN-1:0] dbg_stage_4_memory_transaction_closure_pc = stage_4_memory_transaction_closure.pc;
    logic dbg_stage_4_memory_transaction_closure_valid         = stage_4_memory_transaction_closure.valid;
    `endif

    assign data_memory_w_enable      = stage_4_memory_transaction_closure.control_mem.w_enable && stage_4_memory_transaction_closure.valid;
    assign data_memory_addr          = stage_4_memory_transaction_closure.valid ? stage_4_memory_transaction_closure.compute_result : 'x;
    assign data_memory_width         = stage_4_memory_transaction_closure.control_mem.width;
    assign data_memory_r_sign_extend = stage_4_memory_transaction_closure.control_mem.r_sign_extend;
    assign data_memory_w_data        = stage_4_memory_transaction_closure.control_mem.w_value;

    // =================================
    // STAGE 5: WRITEBACK
    // =================================
    writeback_closure_t stage_5_writeback_closure;
    always_ff @(posedge clock) begin
        if (reset) begin
            stage_5_writeback_closure.valid               <= 1'b0;
            `ifdef SIMULATION
            stage_5_writeback_closure.pc                  <= 'x;
            `endif
            stage_5_writeback_closure.control_reg_write   <= 'x;
            stage_5_writeback_closure.compute_result      <= 'x;
        end else if (backend_is_stalled) begin
            stage_5_writeback_closure.valid               <= stage_5_writeback_closure.valid;
            `ifdef SIMULATION
            stage_5_writeback_closure.pc                  <= stage_5_writeback_closure.pc;
            `endif
            stage_5_writeback_closure.control_reg_write   <= stage_5_writeback_closure.control_reg_write;
            stage_5_writeback_closure.compute_result      <= stage_5_writeback_closure.compute_result;
        end else begin
            stage_5_writeback_closure.valid               <= stage_4_memory_transaction_closure.valid;
            `ifdef SIMULATION
            stage_5_writeback_closure.pc                  <= stage_4_memory_transaction_closure.pc;
            `endif
            stage_5_writeback_closure.control_reg_write   <= stage_4_memory_transaction_closure.control_reg_write;
            stage_5_writeback_closure.compute_result      <= stage_4_memory_transaction_closure.compute_result;
        end
    end

    // Memory reads are synchronous, so we can't capture the memory values as part of our closure
    logic [XLEN-1:0] stage_5_writeback_memory_r_data;
    latch stage_5_writeback_memory_r_data_latch (
        .clock         (clock),
        .reset         (reset),
        .input_value   (data_memory_r_data),
        .update        (!backend_is_stalled),
        .output_value  (stage_5_writeback_memory_r_data)
    );

    `ifdef SIMULATION
    logic [XLEN-1:0] dbg_stage_5_writeback_closure_pc = stage_5_writeback_closure.pc;
    logic dbg_stage_5_writeback_closure_valid         = stage_5_writeback_closure.valid;

    rv_reg_t dbg__stage_5_writeback_closure_control__reg_write__which_register = stage_5_writeback_closure.control_reg_write.which_register;
    logic dbg__stage_5_writeback_closure__control_reg_write__enable            = stage_5_writeback_closure.control_reg_write.enable;
    logic dbg__stage_5_writeback_closure__control_reg_write__source            = stage_5_writeback_closure.control_reg_write.source;
    `endif

    always_comb begin
        register_write_control.enable         = stage_5_writeback_closure.control_reg_write.enable && stage_5_writeback_closure.valid;
        register_write_control.which_register = stage_5_writeback_closure.control_reg_write.which_register;
        case (stage_5_writeback_closure.control_reg_write.source)
            REG_WRITE_FROM_COMPUTE: register_write_control.value = stage_5_writeback_closure.compute_result;
            REG_WRITE_FROM_MEMORY:  register_write_control.value = stage_5_writeback_memory_r_data;
            default:                register_write_control.value = 'x;
        endcase
    end
endmodule;
