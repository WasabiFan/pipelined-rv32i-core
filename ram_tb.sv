`timescale 1ns/1ps

module ram_tb();
    initial begin
        $dumpfile("ram_tb.vcd");
        $dumpvars(0,ram_tb);
    end

    reg clock;
    reg [31:0] addr;
    reg [31:0] w_data;
    write_width_t w_width;
    reg w_enable;
    wire [31:0] r_data;

    ram u_ram (
        .clock    (clock),
        .addr     (addr),
        .w_data   (w_data),
        .w_width  (w_width),
        .w_enable (w_enable),
        .r_data   (r_data)
    );

    initial begin
        clock = 1'b0;
        addr <= 0;
    end

    always begin
        #10 clock = !clock;
    end

    initial begin
        w_enable <= 0;
        // Word-aligned write, full word
        @(posedge clock); w_enable <= 1; addr <= 32'h10; w_width <= write_word; w_data <= 32'h87654321;
        @(posedge clock); w_enable <= 0;
        @(posedge clock);
        @(posedge clock);

        // Word-aligned write, half word
        @(posedge clock); w_enable <= 1; addr <= 32'h14; w_width <= write_halfword;
        @(posedge clock); w_enable <= 0;
        @(posedge clock);
        @(posedge clock);

        // Word-aligned write, single byte
        @(posedge clock); w_enable <= 1; addr <= 32'h18; w_width <= write_byte;
        @(posedge clock); w_enable <= 0;
        @(posedge clock);
        @(posedge clock);

        // Halfword-aligned write, upper, half word
        @(posedge clock); w_enable <= 1; addr <= 32'h1e; w_width <= write_halfword;
        @(posedge clock); w_enable <= 0;
        @(posedge clock);
        @(posedge clock);

        // Halfword-aligned write, upper, half word, overwriting upper halfword from first write
        @(posedge clock); w_enable <= 1; addr <= 32'h12; w_width <= write_halfword; w_data <= 32'hFEDC;
        @(posedge clock); w_enable <= 0;
        @(posedge clock);
        @(posedge clock);                   addr <= 32'h10;
        @(posedge clock);
        @(posedge clock);

        // Byte-aligned write, second of four, single byte, overwriting upper byte of first halfword
        @(posedge clock); w_enable <= 1; addr <= 32'h11; w_width <= write_byte; w_data <= 32'hBA;
        @(posedge clock); w_enable <= 0;
        @(posedge clock);
        @(posedge clock);                   addr <= 32'h10;
        @(posedge clock);
        @(posedge clock);

        // Read from an entirely unrelated address to see read latency
        @(posedge clock);                   addr <= 32'h18;
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);

        $finish;
    end
endmodule
