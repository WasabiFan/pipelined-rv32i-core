module ram(
    input logic clock,
    input logic [XLEN-1:0] addr,
    input logic [XLEN-1:0] w_data,
    input write_width_t w_width,
    input logic w_enable,
    output logic [XLEN-1:0] r_data
);
    parameter depth = 1024;

    reg [XLEN-1:0] memory[0:depth-1];

    logic [1:0] r_addr_offset_within_word, w_addr_offset_within_word;
    logic [XLEN-1:0] addr_whole_word;
    assign addr_whole_word = addr >> 2;
    assign w_addr_offset_within_word = addr[1:0];

    logic [XLEN-1:0] r_data_whole_word, w_data_whole_word;

    // Note: accesses which cross a word-aligned boundary will return erroneous upper zeroes
    assign r_data = r_data_whole_word >> (r_addr_offset_within_word * 8);
    assign w_data_whole_word = w_data << (w_addr_offset_within_word * 8);

    logic [31:0] w_word_write_mask;
    always_comb begin
        case (w_width)
            write_byte:     w_word_write_mask = 32'h000000FF << (w_addr_offset_within_word * 8);
            write_halfword: w_word_write_mask = 32'h0000FFFF << (w_addr_offset_within_word * 8);
            write_word:     w_word_write_mask = 32'hFFFFFFFF;
        endcase
    end

    always_ff @(posedge clock) begin
        if (w_enable) begin
            memory[addr_whole_word] <= (w_data_whole_word & w_word_write_mask) | (memory[addr_whole_word] & ~w_word_write_mask);
        end

        r_addr_offset_within_word <= addr[1:0];
        r_data_whole_word <= memory[addr_whole_word];
    end
endmodule
