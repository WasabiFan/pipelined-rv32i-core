module rom(
    input logic clock,
    input logic [XLEN-1:0] addr,
    output logic [31:0] r_data
);
    // TODO: yosys does parameter replacements before instantiation by default,
    // so using these doesn't actually work. Need to figure out how to pass
    // the -defer option to read_verilog command in the build.
    parameter depth = 1024;
    parameter init_file = "mem.hex";

    reg [31:0] memory[0:depth-1];

    initial begin
        $readmemh(init_file, memory);
    end

    logic [1:0] addr_offset_within_word;
    logic [XLEN-1:0] addr_whole_word;
    assign addr_whole_word = addr >> 2;

    logic [XLEN-1:0] r_data_whole_word;

    // Note: accesses which cross a word-aligned boundary will return erroneous upper zeroes
    assign r_data = r_data_whole_word >> (addr_offset_within_word * 8);

    always_ff @(posedge clock) begin
        addr_offset_within_word <= addr[1:0];
        r_data_whole_word <= memory[addr_whole_word];
    end
endmodule
