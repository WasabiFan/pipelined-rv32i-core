`include "isa_types.sv"
`include "isa_constants.sv"
`include "arch_constants.sv"

module stage_instruction_fetch(
    input logic clock,
    input logic reset,
    input logic enable,
    input logic [XLEN-1:0] pc,
    input logic [XLEN-1:0] mem_r_data,
    output logic is_complete,
    output logic [XLEN-1:0] mem_addr,
    output logic [ILEN-1:0] instr_bits
);
    // TODO: in theory, we could make this a true one-cycle stage by
    // muxing between the incoming register value and our own register.

    logic [1:0] remaining_read_cycles, next_remaining_read_cycles;
    logic is_halted, next_is_halted;

    logic read_complete;
    assign read_complete = remaining_read_cycles == 0;

    // Opcode computed from the current memory output, rather than the captured instr_bits.
    // Used to inform state transitions out of the instruction fetch stage (before we've
    // put the instruction word through our instr_bits latch).
    opcode_t speculative_opcode;
    assign speculative_opcode = extract_opcode(mem_r_data);
    assign next_is_halted = is_halted || (enable && read_complete && speculative_opcode == OPCODE_UNKNOWN);

    assign is_complete = enable && read_complete && ~is_halted && ~next_is_halted;

    assign mem_addr = pc;

    always_comb begin
        // TODO: with the memories on the UPduino, we probably could replace
        // remaining_read_cycles with a single bit 
        if (enable) next_remaining_read_cycles = remaining_read_cycles - 2'b1;
        else        next_remaining_read_cycles = mem_read_latency;
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            is_halted <= 0;
            remaining_read_cycles <= mem_read_latency;
        end else begin
            if (is_complete) begin
                instr_bits <= mem_r_data;
            end
            is_halted <= next_is_halted;
            remaining_read_cycles <= next_remaining_read_cycles;
        end
    end
endmodule