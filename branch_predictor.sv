// 2^10 = 1024 entries
parameter BTB_LOG_NUM_ENTRIES = 10;
parameter BTB_NUM_ENTRIES = 2**BTB_LOG_NUM_ENTRIES;
parameter BTB_INDEX_BITS = BTB_LOG_NUM_ENTRIES;
// Instructions are four-byte-aligned, so ignore the lower two bits
parameter BTB_PC_LOW_BITS_IGNORED = 2;
parameter BTB_TAG_BITS = XLEN - BTB_INDEX_BITS - BTB_PC_LOW_BITS_IGNORED;

typedef enum logic [1:0] {
    BRANCH_NOT_TAKEN,
    BRANCH_WEAK_NOT_TAKEN,
    BRANCH_WEAK_TAKEN,
    BRANCH_TAKEN
} branch_taken_history;

typedef struct packed {
    logic [BTB_TAG_BITS-1:0] tag;
    logic [XLEN-1:0] target;
    branch_taken_history history;
} btb_entry_t;

// Implements a combined Branch Target Buffer + Branch History Table with 2-bit history state.
module branch_predictor(
    input logic clock,
    input logic enable,

    input logic executing_branch_active,
    input logic [XLEN-1:0] executing_branch_pc,
    input logic [XLEN-1:0] executing_branch_target,
    input logic executing_branch_taken,

    input logic [XLEN-1:0] incoming_instruction_pc,

    output logic predicted_jump_target_taken,
    output logic [XLEN-1:0] predicted_jump_target
);

    btb_entry_t btb [0:BTB_NUM_ENTRIES-1];

    logic [BTB_INDEX_BITS-1:0] executing_branch_index, incoming_instruction_index;
    logic [BTB_TAG_BITS-1:0] executing_branch_tag, incoming_instruction_tag;

    assign { executing_branch_tag, executing_branch_index }         = executing_branch_pc     [XLEN-1 : BTB_PC_LOW_BITS_IGNORED];
    assign { incoming_instruction_tag, incoming_instruction_index } = incoming_instruction_pc [XLEN-1 : BTB_PC_LOW_BITS_IGNORED];

    // A branch onto itself, or nearby itself, may track history poorly since it won't be able to
    // re-load those entries.
    btb_entry_t incoming_instruction_entry;
    btb_entry_t instruction_fetch_intermediate_entry;
    btb_entry_t executing_branch_original_entry;

    logic [BTB_TAG_BITS-1:0] incoming_instruction_entry_expected_tag;
    logic executing_branch_original_entry_valid, incoming_instruction_entry_valid;
    assign executing_branch_original_entry_valid = executing_branch_original_entry.tag == executing_branch_tag;
    assign incoming_instruction_entry_valid      = incoming_instruction_entry.tag      == incoming_instruction_entry_expected_tag;

    btb_entry_t executing_branch_new_entry;
    assign executing_branch_new_entry.tag = executing_branch_tag;
    assign executing_branch_new_entry.target = executing_branch_target;
    always_comb begin
        if (executing_branch_original_entry_valid) begin
            case (executing_branch_original_entry.history)
                BRANCH_NOT_TAKEN:      executing_branch_new_entry.history = executing_branch_taken ? BRANCH_WEAK_NOT_TAKEN : BRANCH_NOT_TAKEN;
                BRANCH_WEAK_NOT_TAKEN: executing_branch_new_entry.history = executing_branch_taken ? BRANCH_WEAK_TAKEN     : BRANCH_NOT_TAKEN;
                BRANCH_WEAK_TAKEN:     executing_branch_new_entry.history = executing_branch_taken ? BRANCH_TAKEN          : BRANCH_WEAK_NOT_TAKEN;
                BRANCH_TAKEN:          executing_branch_new_entry.history = executing_branch_taken ? BRANCH_TAKEN          : BRANCH_WEAK_TAKEN;
            endcase
        end else
            executing_branch_new_entry.history = executing_branch_taken ? BRANCH_WEAK_TAKEN : BRANCH_WEAK_NOT_TAKEN;
    end

    always_ff @(posedge clock) begin
        if (executing_branch_active && enable)
            btb[executing_branch_index] <= executing_branch_new_entry;

        if (enable)
            incoming_instruction_entry  <= btb[incoming_instruction_index];

        if (enable) begin
            incoming_instruction_entry_expected_tag <= incoming_instruction_tag;

            instruction_fetch_intermediate_entry <= incoming_instruction_entry;
            executing_branch_original_entry      <= instruction_fetch_intermediate_entry;
        end else begin
            incoming_instruction_entry_expected_tag <= incoming_instruction_entry_expected_tag;

            instruction_fetch_intermediate_entry <= instruction_fetch_intermediate_entry;
            executing_branch_original_entry      <= executing_branch_original_entry;
        end
    end

    always_comb begin
        predicted_jump_target_taken = incoming_instruction_entry_valid && ( incoming_instruction_entry.history == BRANCH_WEAK_TAKEN || incoming_instruction_entry.history == BRANCH_TAKEN );
        predicted_jump_target       = incoming_instruction_entry.target;
    end

endmodule
