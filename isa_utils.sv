`ifndef ISA_UTILS_SV
`define ISA_UTILS_SV

`define SIGEXT(VALUE, FROM, TO) { {(TO-FROM){VALUE[FROM-1]}}, VALUE[FROM-1:0] }
`define ZEXT(VALUE, FROM, TO) { {(TO-FROM){1'b0}}, VALUE[FROM-1:0] }

function logic is_possible_jump;
    input opcode_t opcode;
    logic is_jump;

    case (opcode)
        OPCODE_JAL:    is_jump = 1'b1;
        OPCODE_JALR:   is_jump = 1'b1;
        OPCODE_BRANCH: is_jump = 1'b1;
        default:       is_jump = 1'b0;
    endcase

    return is_jump;
endfunction

`endif