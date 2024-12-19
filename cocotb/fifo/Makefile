#
# Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
#
# GPL-3.0 license
#
# Copyright (C) 2024 Robert Metchev
#

SHELL=/bin/bash
# defaults
SIM ?= verilator
#SIM ?= icarus
#SIM ?= modelsim
export SIM := $(SIM)
TOPLEVEL_LANG ?= verilog

WAVES = 1

# FIFO: SFIFO or AFIFO
FIFO ?= SFIFO
export FIFO := $(FIFO)

VERILOG_SOURCES += \
        $(realpath ../../rtl/fifo/axis_data_fifo_0.sv) \
        $(realpath ../../rtl/fifo/afifo.v) \
        $(realpath ../../rtl/fifo/sfifo.sv) \
        $(realpath ../../rtl/fifo/pipe.sv) \
        $(realpath ../../rtl/bram/dp_ram_be.sv)

VERILOG_INCLUDE_DIRS += $(realpath ../../rtl/include)

ifeq ($(SIM),icarus)
        COMPILE_ARGS += -DAXIS_DATA_FIFO_0_$(FIFO)
        COMPILE_ARGS += -Wall
        COMPILE_ARGS += -v
        #COMPILE_ARGS += -g2005-sv
endif
ifeq ($(SIM),verilator)
        EXTRA_ARGS += +define+AXIS_DATA_FIFO_0_$(FIFO)
        EXTRA_ARGS += --timing
        ifneq ($(WAVES),0)
                EXTRA_ARGS += --trace --trace-structs --trace-fst
        endif
        WNO = WIDTHTRUNC WIDTHEXPAND ASCRANGE EOFNEWLINE PINCONNECTEMPTY DECLFILENAME GENUNNAMED VARHIDDEN UNUSEDPARAM
        EXTRA_ARGS += -Wall $(WNO:%=-Wno-%)
endif

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = axis_data_fifo_0

# MODULE is the basename of the Python test file
MODULE = axis_fifo
export PYTHONPATH := $(realpath .)

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: g gtkwave
g gtkwave:
ifeq ($(SIM),icarus)
	gtkwave sim_build/$(TOPLEVEL).fst -o -a 1.gtkw
endif
ifeq ($(SIM),verilator)
	gtkwave dump.fst -o -a 1.gtkw
endif

clean::
	rm -rf __pycache__ results.xml obj_dir
	rm -rf dump.vcd dump.vcd.fst dump.vcd.fst.hier 
	rm -rf dump.fst dump.fst.hier 
	rm -rf transcript modelsim.ini vsim.wlf vsim_stacktrace.vstf vish_stacktrace.vstf
