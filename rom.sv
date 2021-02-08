module rom(
    input logic clock,
    input logic [XLEN-1:0] addr,
    output logic [31:0] rdata
);
    // TODO: yosys does parameter replacements before instantiation by default,
    // so using these doesn't actually work. Need to figure out how to pass
    // the -defer option to read_verilog command in the build.
    parameter depth = 1024;
    parameter init_file = "mem.hex";

    reg [31:0] memory[0:depth-1];

    initial begin
        $readmemh(init_file, memory);
    end

    always_ff @(posedge clock) begin
        rdata <= memory[addr];
    end
endmodule
