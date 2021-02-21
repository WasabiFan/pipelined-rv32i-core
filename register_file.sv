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
    `ifdef SIMULATION
    logic [XLEN-1:0] reg_x01_ra, reg_x02_sp, reg_x08_s0, reg_x10_a0, reg_x11_a1, reg_x15_a5, reg_x19_s3, reg_x21_s5, reg_x23_s7;
    assign reg_x01_ra = xregs[1];
    assign reg_x02_sp = xregs[2];
    assign reg_x08_s0 = xregs[8];
    assign reg_x10_a0 = xregs[10];
    assign reg_x11_a1 = xregs[11];
    assign reg_x15_a5 = xregs[15];
    assign reg_x19_s3 = xregs[19];
    assign reg_x21_s5 = xregs[21];
    assign reg_x23_s7 = xregs[23];
    `endif

    always_ff @(posedge clock) begin
        if (reset) begin
            xregs[0] <= 0;
            `ifndef SIMULATION
            // Not required, but for reproducibility...
            xregs <= '{default:0};
            `endif
        end else begin
            if (write_control.enable && write_control.which_register != 0) begin // avoid writing to x0
                xregs <= xregs;
                xregs[write_control.which_register] <= write_control.value;
            end else begin
                xregs <= xregs;
            end

            if (write_control.enable && write_control.which_register != 0 && write_control.which_register == rs1)
                rs1_val <= write_control.value;
            else
                rs1_val <= xregs[rs1];

            if (write_control.enable && write_control.which_register != 0 && write_control.which_register == rs2)
                rs2_val <= write_control.value;
            else
                rs2_val <= xregs[rs2];
        end
    end

endmodule;