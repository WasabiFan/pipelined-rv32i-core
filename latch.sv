module latch(
    input logic clock,
    input logic reset,
    input logic [XLEN-1:0] input_value,
    input logic update,
    output logic [XLEN-1:0] output_value
);

    logic [XLEN-1:0] last_value;
    logic last_update;

    always_ff @(posedge clock) begin
        last_update <= update;

        if (reset) begin
            last_value  <= 'x;
            last_update <= 1'b1;
        end else if (update)
            last_value  <= input_value;
        else if (!update && last_update)
            last_value  <= input_value;
        else
            last_value  <= last_value;
    end

    always_comb begin
        if (last_update)
            output_value = input_value;
        else
            output_value = last_value;
    end
endmodule
