module register_file(
    input logic clock,
    input logic reset,

    input rv_reg_t rs1,
    input rv_reg_t rs2,
    input reg_write_control_t write_control,

    output logic [XLEN-1:0] rs1_val,
    output logic [XLEN-1:0] rs2_val
);
    // one register is x0
    parameter num_regs = 32;

    logic [XLEN-1:0] xregs [0:num_regs-1];

    // for debugging in sim
    // logic [XLEN-1:0] ra, sp;
    // assign ra = xregs[1];
    // assign sp = xregs[2];

    always_ff @(posedge clock) begin
        if (reset) begin
            xregs[0] <= 0;
            // Not required, but for reproducibility...
            xregs <= '{default:0};
        end else begin
            if (write_control.enable && write_control.which_register != 0) begin // avoid writing to x0
                xregs <= xregs;
                xregs[write_control.which_register] <= write_control.value;
            end else begin
                xregs <= xregs;
            end

            rs1_val <= xregs[rs1];
            rs2_val <= xregs[rs2];
        end
    end

endmodule;