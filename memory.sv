module memory(
    input logic clock,
    input logic [XLEN-1:0] addr,
    input mem_width_t r_width,
    input logic r_sign_extend,
    input logic [XLEN-1:0] w_data,
    input mem_width_t w_width,
    input logic w_enable,
    input logic [XLEN-1:0] memory_mapped_io_r_data,
    output logic [XLEN-1:0] r_data,
    output mem_write_control_t memory_mapped_io_control
);
    parameter ram_start_addr = 32'h00020000;
    parameter ram_depth = 1024;

    logic w_is_data_ram_active;
    assign w_is_data_ram_active = addr >= ram_start_addr && addr < (ram_start_addr + ram_depth * 4);

    logic [XLEN-1:0] ram_r_data;
    ram #(.depth(ram_depth)) data_memory (
        .clock       (clock),
        // RAM cell mapped starting at the ram_start address
        .addr        (addr - ram_start_addr),
        .w_data      (w_data),
        .w_width     (w_width),
        .w_enable    (w_enable && w_is_data_ram_active),
        .r_data      (ram_r_data)
    );

    logic r_is_data_ram_active, stored_r_sign_extend;
    mem_width_t stored_r_width;
    always_ff @(posedge clock) begin
        r_is_data_ram_active <= w_is_data_ram_active;
        stored_r_sign_extend <= r_sign_extend;
        stored_r_width       <= r_width;
    end

    logic [XLEN-1:0] r_data_unextended;
    assign r_data_unextended = r_is_data_ram_active ? ram_r_data : memory_mapped_io_r_data;

    always_comb begin
        if (stored_r_sign_extend) begin
            case (stored_r_width)
                WIDTH_BYTE:     r_data = `SIGEXT( r_data_unextended, 8,  XLEN );
                WIDTH_HALFWORD: r_data = `SIGEXT( r_data_unextended, 16, XLEN );
                WIDTH_WORD:     r_data =          r_data_unextended;
                default:        r_data = 'x;
            endcase
        end else begin
            case (stored_r_width)
                WIDTH_BYTE:     r_data = `ZEXT( r_data_unextended, 8,  XLEN );
                WIDTH_HALFWORD: r_data = `ZEXT( r_data_unextended, 16, XLEN );
                WIDTH_WORD:     r_data =        r_data_unextended;
                default:        r_data = 'x;
            endcase
        end
    end

    assign memory_mapped_io_control.addr = addr;
    assign memory_mapped_io_control.value = w_data;
    assign memory_mapped_io_control.width = w_width;
    assign memory_mapped_io_control.enable = w_enable && !w_is_data_ram_active;

endmodule;
