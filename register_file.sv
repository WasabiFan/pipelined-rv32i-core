// one register is x0
parameter num_regs = 32;

module register_file_half(
    input logic clock,

    input rv_reg_t rs,
    input reg_write_control_t write_control,

    output logic [XLEN-1:0] val
);
    logic [XLEN-1:0] xregs [0:num_regs-1];

    reg_write_control_t last_write_control;
    logic [XLEN-1:0] last_read_val;
    rv_reg_t last_rs;

    always_ff @(posedge clock) begin
        if (write_control.enable)
            xregs[write_control.which_register] <= write_control.value;

        last_write_control <= write_control;
        last_read_val <= xregs[rs];
        last_rs <= rs;
    end

    always_comb begin
        if (last_rs == 0)
            val = 0;
        else if (last_write_control.enable && last_write_control.which_register == last_rs)
            val = last_write_control.value;
        else
            val = last_read_val;
    end
endmodule

module register_file(
    input logic clock,

    input rv_reg_t rs1,
    input rv_reg_t rs2,
    input reg_write_control_t write_control,

    output logic [XLEN-1:0] rs1_val,
    output logic [XLEN-1:0] rs2_val
);

    // for debugging in sim
    `ifdef SIMULATION
    logic [XLEN-1:0] reg_x01_ra, reg_x02_sp, reg_x08_s0, reg_x10_a0, reg_x11_a1, reg_x15_a5, reg_x19_s3, reg_x21_s5, reg_x23_s7;
    assign reg_x01_ra = rs1_half.xregs[1];
    assign reg_x02_sp = rs1_half.xregs[2];
    assign reg_x08_s0 = rs1_half.xregs[8];
    assign reg_x10_a0 = rs1_half.xregs[10];
    assign reg_x11_a1 = rs1_half.xregs[11];
    assign reg_x15_a5 = rs1_half.xregs[15];
    assign reg_x19_s3 = rs1_half.xregs[19];
    assign reg_x21_s5 = rs1_half.xregs[21];
    assign reg_x23_s7 = rs1_half.xregs[23];
    `endif

    register_file_half rs1_half (
        .clock            (clock),
        .rs               (rs1),
        .write_control    (write_control),
        .val              (rs1_val)
    );

    register_file_half rs2_half (
        .clock            (clock),
        .rs               (rs2),
        .write_control    (write_control),
        .val              (rs2_val)
    );
endmodule;