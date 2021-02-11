`include "isa_types.sv"

module top (
    input wire gpio_2,
    output wire led_red,
    output wire led_blue,
    output wire led_green,
    output wire spi_cs,
    output wire serial_txd
);
    // Explicitly disable the SPI flash since it shares data lines with UART
    assign spi_cs = 1'b1;

    // Use GPIO pin 2 as reset. Tie to ground for reset. "reset" here is active-high.
    logic reset;
    assign reset = ~gpio_2;

    logic  int_osc;

    // Internal oscillator
    /* verilator lint_off PINMISSING */
    SB_HFOSC u_SB_HFOSC (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(int_osc));
    /* verilator lint_on PINMISSING */

    // Serial transmitter
    logic [7:0] serial_tx_data;
    logic serial_tx_data_available, serial_tx_ready;
    serial_transmitter serial_out (
        .clock                (int_osc),
        .reset                (reset),
        .tx_data              (serial_tx_data),
        .tx_data_available    (serial_tx_data_available),
        .tx_ready             (serial_tx_ready),
        .serial_tx            (serial_txd)
    );

    logic [XLEN-1:0] memory_mapped_io_r_data;
    logic memory_mapped_io_write_complete;
    mem_write_control_t memory_mapped_io_control;
    hart core (
        .clock                           (int_osc),
        .reset                           (reset),
        .memory_mapped_io_r_data         (memory_mapped_io_r_data),
        .memory_mapped_io_write_complete (memory_mapped_io_write_complete),
        .memory_mapped_io_control        (memory_mapped_io_control)
    );

    logic serial_tx_write_started;
    always_ff @(posedge int_osc) begin
        if (reset) begin
            serial_tx_write_started <= 1'b0;
        end else begin
            if (!memory_mapped_io_control.enable)
                serial_tx_write_started <= 1'b0;
            else if (!serial_tx_ready)
                serial_tx_write_started <= 1'b1;
            else
                serial_tx_write_started <= serial_tx_write_started;
        end
    end

    always_comb begin
        serial_tx_data = 'x;
        serial_tx_data_available = 1'b0;
        memory_mapped_io_write_complete = 1'b0;

        if (memory_mapped_io_control.addr == 32'h00030000 && memory_mapped_io_control.width == write_byte && memory_mapped_io_control.enable) begin
            serial_tx_data = memory_mapped_io_control.value[7:0];
            serial_tx_data_available = 1'b1;
            memory_mapped_io_write_complete = serial_tx_write_started && serial_tx_data_available;
        end
        
        if (memory_mapped_io_control.addr == 32'h00030004 && memory_mapped_io_control.enable) begin
            memory_mapped_io_write_complete = 1'b1;
        end

        if (memory_mapped_io_control.addr == 32'h00030008 && memory_mapped_io_control.enable) begin
            memory_mapped_io_write_complete = 1'b1;
        end
    end

    assign memory_mapped_io_r_data = '0;

    logic led_blue_control, led_green_control;
    always_ff @(posedge int_osc) begin
        if (reset) begin
            led_blue_control <= 1'b0;
            led_green_control <= 1'b0;
        end else begin
            led_blue_control <= led_blue_control;
            led_green_control <= led_green_control;

            if (memory_mapped_io_control.addr == 32'h00030004 && memory_mapped_io_control.enable) begin
                led_blue_control <= memory_mapped_io_control.value != 0;
            end

            if (memory_mapped_io_control.addr == 32'h00030008 && memory_mapped_io_control.enable) begin
                led_green_control <= memory_mapped_io_control.value != 0;
            end
        end
    end

    // LED driver
    SB_RGBA_DRV RGB_DRIVER (
        .RGBLEDEN(1'b1                                            ),
        .RGB0PWM (led_blue_control),
        .RGB1PWM (led_green_control),
        // red LED tied to "reset" to indicate when you're triggering reset
        .RGB2PWM (reset                                           ),
        .CURREN  (1'b1                                            ),
        .RGB0    (led_green                                       ),
        .RGB1    (led_blue                                        ),
        .RGB2    (led_red                                         )
    );
    defparam RGB_DRIVER.RGB0_CURRENT = "0b000001";
    defparam RGB_DRIVER.RGB1_CURRENT = "0b000001";
    defparam RGB_DRIVER.RGB2_CURRENT = "0b000001";
endmodule
