`timescale 1ns/1ps

module rom_tb();
    initial begin
        $dumpfile("rom_tb.vcd");
        $dumpvars(0,rom_tb);
    end

    reg clock;
    reg [31:0] addr;
    wire [31:0] r_data;

    rom u_rom (
        .clock    (clock),
        .addr     (addr),
        .r_data    (r_data)
    );

    initial begin
        clock = 1'b0;
        addr <= 0;
    end

    always begin
        #10 clock = !clock;
    end

    initial begin
        repeat(5000) begin
            @(posedge clock); addr <= addr + 1;
        end

        $finish;
    end
endmodule
