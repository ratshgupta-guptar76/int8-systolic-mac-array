SHELL := /bin/bash

# Paths
RTL_DIR := rtl
TB_DIR := test
SIM_DIR := sim

# Sources
TOP := pe_tb
RTL_SOURCES := $(RTL_DIR)/pe.sv
TB_SOURCES := $(TB_DIR)/pe_tb.sv

# Verilator build output
SIM_EXE := pe_sim
SIM_BIN := $(SIM_DIR)/$(SIM_EXE)

# Verilator options
VERILATOR := verilator
VERILATOR_FLAGS := --sv --binary --top-module $(TOP) --Mdir $(SIM_DIR) -Wall -Wno-fatal

.PHONY: all build run clean

all: run

build: $(SIM_BIN)

$(SIM_BIN): $(RTL_SOURCES) $(TB_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL_SOURCES) $(TB_SOURCES) -o $(SIM_EXE)

run: build
	./$(SIM_BIN)

clean:
	rm -rf $(SIM_DIR)/*
	rm -f *.vcd *.fst
