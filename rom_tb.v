`timescale 1ns/1ps

module rom_tb();
    initial begin
        $dumpfile("rom_tb.vcd");
        $dumpvars(0,rom_tb);
    end

    reg clock;
    reg [31:0] addr;
    wire [31:0] rdata;

    rom #(
        // TODO: transpile testbenches with sv2v to avoid this 
        ._sv2v_width_init_file(14*8),
        .init_file("rom_tb_mem.hex")
    ) u_rom (
        .clock    (clock),
        .addr     (addr),
        .rdata    (rdata)
    );

    initial begin
        clock = 1'b0;
        addr <= 0;
    end

    always begin
        #10 clock = !clock;
    end

    initial begin
        repeat(2000) begin
            @(posedge clock); addr <= addr + 1;
        end

        $finish;
    end
endmodule
