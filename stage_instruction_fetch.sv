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

    logic [0:0] remaining_read_cycles, next_remaining_read_cycles;
    logic is_halted, next_is_halted;

    logic read_complete;
    assign read_complete = remaining_read_cycles == 0;

    // Opcode computed from the current memory output, rather than the captured instr_bits.
    opcode_t speculative_opcode;
    assign speculative_opcode = extract_opcode(mem_r_data);
    assign next_is_halted = is_halted || (enable && read_complete && speculative_opcode == OPCODE_UNKNOWN);

    logic read_in_progress;
    assign read_in_progress = enable && ~is_halted && ~next_is_halted;
    assign is_complete = read_in_progress && read_complete;

    assign mem_addr = pc;

    always_comb begin
        // TODO: with the memories on the UPduino, we probably could replace
        // remaining_read_cycles with a single bit 
        if (enable) next_remaining_read_cycles = remaining_read_cycles - 1'b1;
        else        next_remaining_read_cycles = mem_read_latency;

        if (read_in_progress) instr_bits = mem_r_data;
        else                  instr_bits = saved_instr_bits;
    end

    logic [ILEN-1:0] saved_instr_bits;

    always_ff @(posedge clock) begin
        if (reset) begin
            is_halted <= 0;
            remaining_read_cycles <= mem_read_latency;
            saved_instr_bits <= 32'hxxxxxxxx;
        end else begin
            if (is_complete) begin
                saved_instr_bits <= mem_r_data;
            end else begin
                saved_instr_bits <= saved_instr_bits;
            end
            is_halted <= next_is_halted;
            remaining_read_cycles <= next_remaining_read_cycles;
        end
    end
endmodule