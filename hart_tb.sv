`timescale 1ns/1ps

module hart_tb();
    initial begin
        $dumpfile("hart_tb.vcd");
        $dumpvars(0,hart_tb);
    end

    logic clock, reset;
    
    logic [XLEN-1:0] memory_mapped_io_r_data;
    logic memory_mapped_io_write_complete;
    mem_write_control_t memory_mapped_io_control;

    logic [XLEN-1:0] memory_mapped_io_addr;
    logic [XLEN-1:0] memory_mapped_io_value;
    write_width_t memory_mapped_io_width;
    logic memory_mapped_io_enable;

    assign memory_mapped_io_addr   = memory_mapped_io_control.addr;
    assign memory_mapped_io_value  = memory_mapped_io_control.value;
    assign memory_mapped_io_width  = memory_mapped_io_control.width;
    assign memory_mapped_io_enable = memory_mapped_io_control.enable;

    hart #(
        // TODO: the testbench is transpiled without the main sources included,
        // so sv2v doesn't introduce this automatically. Should consider
        // including all sources in each individual testbench.
        ._sv2v_width_rom_init_file(15*8),
        .rom_init_file("hart_tb_mem.hex")
    ) dut (
        .clock                           (clock),
        .reset                           (reset),
        .memory_mapped_io_r_data         (memory_mapped_io_r_data),
        .memory_mapped_io_write_complete (memory_mapped_io_write_complete),
        .memory_mapped_io_control        (memory_mapped_io_control)
    );

    assign memory_mapped_io_write_complete = 1'b1;

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
