`timescale 1ns/1ps

module hart_tb();
    initial begin
        $dumpfile("hart_tb.vcd");
        $dumpvars(0,hart_tb);
    end

    logic clock, reset;

    hart #(
        // TODO: the testbench is transpiled without the main sources included,
        // so sv2v doesn't introduce this automatically. Should consider
        // including all sources in each individual testbench.
        ._sv2v_width_rom_init_file(15*8),
        .rom_init_file("hart_tb_mem.hex")
    ) dut (
        .clock    (clock),
        .reset    (reset)
    );

    initial begin
        clock = 1'b0;
    end

    always begin
        #10 clock = !clock;
    end

    initial begin
        reset <= 1'b1;
        @(posedge clock); reset <= 1'b0;
        repeat(5000) @(posedge clock);

        $finish;
    end
endmodule
