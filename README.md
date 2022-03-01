# Toy 5-stage in-order RISC-V CPU

This repo houses my implementation of a 5-stage RV32I core and simple SOC peripherals for testing. It targets the [UPduino](https://tinyvision.ai/products/upduino-v3-0) ICE40 development board, although pretty much any ICE40-based dev board should work with minimal changes to the build scripts.

This repo is descended from my [UPduino template project](https://github.com/WasabiFan/apio-upduino-template), and as such it uses a fully open-source toolchain.

This core was implemented for a computer architecture class I took at University of Washington. The minimal C standard library replacement in the `firmware/` folder is derived from sample code provided by the professor, Mark Oskin. I have made miscellaneous modifications. All other contents of this repository are mine.

This was my second RV32I core, and first pipelined design. It's likely not suited for any real workloads. However, I do feel it is well-written and am happy with the results.

`hart.sv` is the root module for the core. `top.sv` is the true top module, which instantiates the core with some peripherals.

## Features and details

- RV32I core with 5-stage in-order pipeline
- Harvard architecture (separate instruction and data memories)
- Branch prediction with a combined Branch Target Buffer (BTB) and Branch History Table (BHT)
  - When run in simulation, performance counters for branch prediction effectiveness
- Memory and register file synthesize to hardened SRAMs
- UART transmitter peripheral with associated stdlib support

Note that BTB and BHT designs are quite nuanced, and my implementation was written in an afternoon after reading seminal papers on the subject. I make no guarantees on optimality or even true correctness. That being said, it seems to work pretty well.

## License

I'm witholding the license on this code because some of the software libraries were provided by a professor and are not mine to redistribute. The core I have implemented is also not particularly well verified and I can't imagine a sensible use-case. However, if, against your better judgement, you are in some way interested in using code of mine from this repo, please reach out.

This should go without saying, but: **if you are a student, you may not use anything in this repo for your own assignments.**

## Development environment

The Makefile requires GNU Make, so Linux is the expected host environment. I use Ubuntu 20.04.

On Windows, you can install VMware (I use VMware Workstation, although Fusion would probably also work) and run a Linux virtual machine within it. Once the virtual machine is running, if you plug in the UPduino, VMware will prompt you to choose what it does with the device; select the option to connect it to your VM. You can tell it to remember this choice for the future.

All future commands will assume a Linux environment.

### System setup

The following steps are specific to Ubuntu. Similar steps will work for other Linux distributions.

First, install Python, apio, dependencies and necessary tools:

```bash
# Python and pip
sudo apt install -y python3-pip git

# gtkwave
sudo apt install -y gtkwave screen

# apio
pip3 install --user apio

echo 'export PATH="$PATH:${HOME}/.local/bin"' >> ~/.bashrc
export PATH="$PATH:${HOME}/.local/bin"

# apio packages
apio install system scons yosys ice40 iverilog verilator
```

Install sv2v (the below will put it in `~/.bin/`, but feel free to choose a different location):

```bash
# sv2v
mkdir ~/.bin/ && cd ~/.bin/
wget https://github.com/zachjs/sv2v/releases/download/v0.0.6/sv2v-Linux.zip
unzip sv2v-Linux.zip

echo 'export PATH="$PATH:${HOME}/.bin/sv2v-Linux"' >> ~/.bashrc
```

Add your user account to the necessary groups for accessing the serial port:

```
sudo usermod -aG tty $USER
sudo usermod -aG dialout $USER
```

Create an appropriate udev rule for the USB device. Here's a one-liner command to do this:

```bash
echo "ATTRS{idVendor}==\"0403\", ATTRS{idProduct}==\"6014\", MODE=\"0660\", GROUP=\"plugdev\", TAG+=\"uaccess\"" | sudo tee /etc/udev/rules.d/53-lattice-ftdi.rules
```

Reload the udev rules so the new one is picked up without reboot:

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## Usage

See the list of `make` targets below.

Note that the reset pin is, by default, pin 2. It is active-low, so tie it to GND to reset.

## `make` targets

- `make verify`: run your code through Icarus Verilog compiler.
- `make lint`: lint your code with `verilator`.
- `make build`: synthesize your code for the UPduino.
- `make sim-MODNAME`: simulate the testbench called `MODNAME_tb.sv` and open the results in `gtkwave`.
- `make upload`: synthesize and upload to a real board.
