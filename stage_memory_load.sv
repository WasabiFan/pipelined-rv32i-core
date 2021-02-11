`include "isa_constants.sv"

module stage_memory_load(
    input logic clock,
    input logic reset,
    input logic enable,
    input logic [XLEN-1:0] i_effective_addr,
    input logic [XLEN-1:0] mem_r_data,
    output logic is_complete,
    output logic [XLEN-1:0] mem_addr,
    output logic [XLEN-1:0] loaded_value
);
    logic [0:0] remaining_read_cycles, next_remaining_read_cycles;

    logic read_complete;
    assign read_complete = remaining_read_cycles == 0;

    assign is_complete = enable && read_complete;

    assign mem_addr = i_effective_addr;

    always_comb begin
        if (enable) next_remaining_read_cycles = remaining_read_cycles - 1'b1;
        else        next_remaining_read_cycles = mem_read_latency;
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            remaining_read_cycles <= mem_read_latency;
        end else begin
            if (is_complete) begin
                loaded_value <= mem_r_data;
            end
            remaining_read_cycles <= next_remaining_read_cycles;
        end
    end
endmodule
