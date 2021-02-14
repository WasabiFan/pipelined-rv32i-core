module ram(
    input logic clock,
    input logic [XLEN-1:0] addr,
    input logic [XLEN-1:0] w_data,
    input write_width_t w_width,
    input logic w_enable,
    output logic [XLEN-1:0] r_data
);
    parameter depth = 1024;
    parameter init_file = "mem_data.hex";

    reg [XLEN-1:0] memory[0:depth-1];

    initial begin
        $readmemh(init_file, memory);
    end

    logic [1:0] r_addr_offset_within_word, w_addr_offset_within_word;
    logic [XLEN-1:0] addr_whole_word;
    assign addr_whole_word = addr >> 2;
    assign w_addr_offset_within_word = addr[1:0];

    logic [XLEN-1:0] r_data_whole_word, w_data_whole_word;

    // Note: accesses which cross a word-aligned boundary will return erroneous upper zeroes
    assign r_data = r_data_whole_word >> (r_addr_offset_within_word * 8);
    assign w_data_whole_word = w_data << (w_addr_offset_within_word * 8);

    logic [3:0] w_word_byte_enable;
    always_comb begin
        case (w_width)
            write_byte:     w_word_byte_enable = 4'b0001 << w_addr_offset_within_word;
            write_halfword: w_word_byte_enable = 4'b0011 << w_addr_offset_within_word;
            write_word:     w_word_byte_enable = 4'b1111;
            default:        w_word_byte_enable = 4'b0000; // Shouldn't happen
        endcase
    end

    always_ff @(posedge clock) begin
        if (w_enable) begin
            if (w_word_byte_enable[0])
                memory[addr_whole_word][7:0] <= w_data_whole_word[7:0];

            if (w_word_byte_enable[1])
                memory[addr_whole_word][15:8] <= w_data_whole_word[15:8];

            if (w_word_byte_enable[2])
                memory[addr_whole_word][23:16] <= w_data_whole_word[23:16];

            if (w_word_byte_enable[3])
                memory[addr_whole_word][31:24] <= w_data_whole_word[31:24];
        end

        r_addr_offset_within_word <= addr[1:0];
        r_data_whole_word <= memory[addr_whole_word];
    end
endmodule
