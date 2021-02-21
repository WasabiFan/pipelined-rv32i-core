module operand_forwarder(
    input rv_reg_t rs,
    input logic [XLEN-1:0] rs_value,
    input logic stage_4_memory_transaction_closure_valid,
    input compute_reg_control_t stage_4_memory_transaction_register_control,
    input logic [XLEN-1:0] stage_4_memory_transaction_compute_result,
    input logic stage_5_writeback_closure_valid,
    input compute_reg_control_t stage_5_writeback_register_control,
    input logic [XLEN-1:0] stage_5_writeback_compute_result,
    input logic [XLEN-1:0] stage_5_writeback_memory_r_data,
    output logic valid,
    output logic [XLEN-1:0] operand_value
);

    always_comb begin
        if (rs == 0) begin
            // avoid false dependency on x0
            valid = 1'b1;
            operand_value = rs_value;
        end else if (
                stage_4_memory_transaction_closure_valid
                && stage_4_memory_transaction_register_control.enable
                && stage_4_memory_transaction_register_control.which_register == rs
        ) begin
            case (stage_4_memory_transaction_register_control.source)
                REG_WRITE_FROM_COMPUTE: begin
                    valid = 1'b1;
                    operand_value = stage_4_memory_transaction_compute_result;
                end
                REG_WRITE_FROM_MEMORY: begin
                    valid = 1'b0;
                    operand_value = 'x;
                end
                default: begin
                    valid = 1'b0;
                    operand_value = 'x;
                end
            endcase
        end else if (
                stage_5_writeback_closure_valid
                && stage_5_writeback_register_control.enable
                && stage_5_writeback_register_control.which_register == rs
        ) begin
            case (stage_5_writeback_register_control.source)
                REG_WRITE_FROM_COMPUTE: begin
                    valid = 1'b1;
                    operand_value = stage_5_writeback_compute_result;
                end
                REG_WRITE_FROM_MEMORY: begin
                    valid = 1'b1;
                    operand_value = stage_5_writeback_memory_r_data;
                end
                default: begin
                    valid = 1'b0;
                    operand_value = 'x;
                end
            endcase
        end else begin
            valid = 1'b1;
            operand_value = rs_value;
        end
    end

endmodule