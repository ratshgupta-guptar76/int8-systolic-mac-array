SHELL := /bin/bash

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
RTL_DIR := $(ROOT_DIR)/rtl
TB_DIR := $(ROOT_DIR)/test
SIM_DIR := $(ROOT_DIR)/sim
PY_TB_DIR := $(TB_DIR)/py_tests

VERILATOR ?= verilator
VERILATOR_FLAGS ?= --sv --binary -Wall -Wno-fatal

RTL_SOURCES := $(wildcard $(RTL_DIR)/*.sv)
TB_SOURCES := $(wildcard $(TB_DIR)/*_tb.sv)
MODULES := $(patsubst %_tb,%,$(basename $(notdir $(TB_SOURCES))))

# SV testbench selector (e.g. make test MODULE=skew)
MODULE ?= skew

# cocotb defaults (e.g. make cocotb PY_MODULE=test_array)
PY_SIM ?= verilator
PY_TOPLEVEL_LANG ?= verilog
PY_TOPLEVEL ?= systolic_array
PY_MODULE ?= test_array
PY_VERILOG_SOURCES := $(RTL_DIR)/pe.sv $(RTL_DIR)/skew.sv $(RTL_DIR)/systolic_array.sv

.PHONY: all help test test-all cocotb waves clean

all: test

help:
	@echo "Targets:"
	@echo "  make test MODULE=<name>   Run one SystemVerilog testbench (default MODULE=skew)"
	@echo "  make test-all             Run all *_tb.sv testbenches"
	@echo "  make cocotb               Run cocotb test (defaults to PY_MODULE=test_array)"
	@echo "  make waves                Open cocotb dump in GTKWave with auto-grouped signals"
	@echo "  make clean                Remove simulation artifacts"

test:
	@set -e; \
	if [[ ! -f "$(TB_DIR)/$(MODULE)_tb.sv" ]]; then \
		echo "Testbench not found: $(TB_DIR)/$(MODULE)_tb.sv"; \
		echo "Available modules: $(MODULES)"; \
		exit 1; \
	fi; \
	mkdir -p $(SIM_DIR); \
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module $(MODULE)_tb \
		--Mdir $(SIM_DIR)/$(MODULE)_obj \
		$(RTL_SOURCES) $(TB_DIR)/$(MODULE)_tb.sv \
		-o $(MODULE)_sim; \
	$(SIM_DIR)/$(MODULE)_obj/$(MODULE)_sim

test-all:
	@set -e; \
	if [[ -z "$(MODULES)" ]]; then \
		echo "No testbenches found in $(TB_DIR)."; \
		exit 1; \
	fi; \
	for mod in $(MODULES); do \
		echo "== Running $$mod_tb =="; \
		$(MAKE) --no-print-directory test MODULE=$$mod; \
	done

cocotb:
	@set -e; \
	cocotb_makefiles=""; \
	if command -v cocotb-config >/dev/null 2>&1; then \
		cocotb_makefiles="$$(cocotb-config --makefiles)"; \
	elif [[ -x "$(ROOT_DIR)/.venv/bin/python" ]] && "$(ROOT_DIR)/.venv/bin/python" -m cocotb_tools.config --makefiles >/dev/null 2>&1; then \
		cocotb_makefiles="$$("$(ROOT_DIR)/.venv/bin/python" -m cocotb_tools.config --makefiles)"; \
	elif python3 -m cocotb_tools.config --makefiles >/dev/null 2>&1; then \
		cocotb_makefiles="$$(python3 -m cocotb_tools.config --makefiles)"; \
	else \
		echo "cocotb not found. Install it in .venv: source .venv/bin/activate && python -m pip install cocotb"; \
		exit 1; \
	fi; \
	extra_args=""; \
	if [[ "$(PY_SIM)" == "verilator" ]]; then \
		extra_args="--trace --trace-structs"; \
	fi; \
	cd $(PY_TB_DIR); \
	SIM=$(PY_SIM) \
	TOPLEVEL_LANG=$(PY_TOPLEVEL_LANG) \
	VERILOG_SOURCES="$(PY_VERILOG_SOURCES)" \
	TOPLEVEL=$(PY_TOPLEVEL) \
	COCOTB_TEST_MODULES=$(PY_MODULE) \
	EXTRA_ARGS="$$extra_args" \
	$(MAKE) -f "$$cocotb_makefiles"/Makefile.sim

waves:
	@set -e; \
	wave_file="$(PY_TB_DIR)/dump.vcd"; \
	script_file="$(PY_TB_DIR)/gtkwave_groups.tcl"; \
	if [[ ! -f "$$wave_file" ]]; then \
		echo "Wave dump not found: $$wave_file"; \
		echo "Run 'make cocotb' first to generate it."; \
		exit 1; \
	fi; \
	if ! command -v gtkwave >/dev/null 2>&1; then \
		echo "gtkwave is not installed. Install with: sudo apt install gtkwave"; \
		exit 1; \
	fi; \
	gtkwave -S "$$script_file" "$$wave_file"

clean:
	rm -rf $(SIM_DIR)/* $(PY_TB_DIR)/sim_build
	rm -f *.vcd *.fst
