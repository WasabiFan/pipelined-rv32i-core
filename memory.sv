module memory(
    input logic clock,
    input logic [XLEN-1:0] addr,
    input logic [XLEN-1:0] w_data,
    input write_width_t w_width,
    input logic w_enable,
    input logic [XLEN-1:0] memory_mapped_io_r_data,
    output logic [XLEN-1:0] r_data,
    output mem_write_control_t memory_mapped_io_control
);
    parameter ram_start_addr = 32'h00020000;
    parameter ram_depth = 1024;
    parameter init_file = "mem_data.hex";

    logic is_data_ram_active;
    assign is_data_ram_active = addr >= ram_start_addr && addr < (ram_start_addr + ram_depth * 4);

    logic [XLEN-1:0] ram_r_data;
    ram #(.depth(ram_depth), .init_file(init_file)) data_memory (
        .clock       (clock),
        // RAM cell mapped starting at the ram_start address
        .addr        (addr - ram_start_addr),
        .w_data      (w_data),
        .w_width     (w_width),
        .w_enable    (w_enable && is_data_ram_active),
        .r_data      (ram_r_data)
    );

    assign r_data = is_data_ram_active ? ram_r_data : memory_mapped_io_r_data;

    assign memory_mapped_io_control.addr = addr;
    assign memory_mapped_io_control.value = w_data;
    assign memory_mapped_io_control.width = w_width;
    assign memory_mapped_io_control.enable = w_enable && !is_data_ram_active;

endmodule;
