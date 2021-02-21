SOURCE_SV_FILES := $(filter-out $(wildcard ./*_tb.sv), $(wildcard ./*.sv))

YOSYS_ROOT = $(shell dirname $(shell dirname $(shell apio raw "which yosys")))
IVERILOG_ROOT = $(shell dirname $(shell dirname $(shell apio raw "which iverilog")))
CELLS_SIM_PATH = $(join $(YOSYS_ROOT),/share/yosys/ice40/cells_sim.v)

FIRMWARE_HEX = firmware/firmware_data.hex firmware/firmware_text.hex

all: all.v verify lint build

# For some features, such as packages, sv2v requires being able to process all
# sources at once and output a single Verilog file. So we have it combine them
# into "all.v".
all.v: $(SOURCE_SV_FILES)
	sv2v $^ > $@

all_sim.v: $(SOURCE_SV_FILES)
	sv2v $^ -D SIMULATION > $@

verify: all.v
	apio raw "iverilog -B \"$(IVERILOG_ROOT)/lib/ivl\" -o hardware.out -D VCD_OUTPUT= $(CELLS_SIM_PATH) all.v"

# "apio lint" lints all.v, but it's preferrable if the linter is operating
# on our original SV source instead.
# Note: verilator does not work with non-synthesizable language features,
# so testbenches aren't linted.
lint:
	apio raw "verilator --lint-only --top-module top -v $(CELLS_SIM_PATH) $(SOURCE_SV_FILES)"


.PHONY: firmware
firmware:
	$(MAKE) -C firmware $(notdir $(FIRMWARE_HEX))

.PHONY: bin
build: hardware.bin

hardware.json: $(FIRMWARE_HEX) all.v
	apio raw "yosys -p \"synth_ice40 -json hardware.json\" -q all.v"

hardware.asc: $(FIRMWARE_HEX) hardware.json upduino.pcf
	apio raw "nextpnr-ice40 --up5k --package sg48 --json hardware.json --asc hardware.asc --pcf upduino.pcf -q"

hardware.bin: hardware.asc
	apio raw "icepack hardware.asc hardware.bin"

# Phony target which performs the end-to-end synthesis with full debug output
build-verbose: $(FIRMWARE_HEX) all.v
	apio raw "yosys -p \"synth_ice40 -json hardware.json\" all.v"
	apio raw "nextpnr-ice40 --up5k --package sg48 --json hardware.json --asc hardware.asc --pcf upduino.pcf"
	apio raw "icepack hardware.asc hardware.bin"

upload: hardware.bin
	apio raw "iceprog -d i:0x0403:0x6014:0 hardware.bin"

%_tb.v: isa_types.sv %_tb.sv
	sv2v $^ > $@

# Apio only supports one testbench (it adds all *_tb.v files at once); the below
# is an expansion of their original rules, with support for multiple testbenches.
%_tb.out: all_sim.v %_tb.v
	apio raw "iverilog -B \"$(IVERILOG_ROOT)/lib/ivl\" -o $@ -D VCD_OUTPUT=$(basename $@) -D SIMULATION $(CELLS_SIM_PATH) $^"

%_tb.vcd: %_tb.out
	apio raw "vvp -M \"$(IVERILOG_ROOT)/lib/ivl\" $<"

# testbenches should be SystemVerilog files ending in "_tb.sv". For some file
# "mymodule_tb.sv", simulate with "make sim-mymodule".
sim-%: %_tb.vcd
	apio raw "gtkwave $< $(patsubst %.vcd, %.gtkw, $<)"

clean:
	apio clean
	rm -f all.v all_sim.v *_tb.vcd *_tb.out *_tb.v
	$(MAKE) -C firmware clean
