SHELL := /bin/bash

# Paths
RTL_DIR := rtl
TB_DIR := test
SIM_DIR := sim

# Sources
RTL_SOURCES := $(wildcard $(RTL_DIR)/*.sv)
TB_SOURCES := $(wildcard $(TB_DIR)/*_tb.sv)
MODULES := $(patsubst %_tb,%,$(basename $(notdir $(TB_SOURCES))))

# Optional module selector:
# - make test MODULE=pe
# - make test pe
MODULE ?=
ifneq ($(filter test tests,$(firstword $(MAKECMDGOALS))),)
ifneq ($(word 2,$(MAKECMDGOALS)),)
MODULE := $(word 2,$(MAKECMDGOALS))
endif
endif

# Verilator options
VERILATOR := verilator
VERILATOR_FLAGS := --sv --binary -Wall -Wno-fatal

.PHONY: all build run test tests build-module run-module clean

all: run

build:
	@set -e; \
	if [[ -z "$(MODULES)" ]]; then \
		echo "No testbenches found in $(TB_DIR). Expected files like <module>_tb.sv"; \
		exit 1; \
	fi; \
	for mod in $(MODULES); do \
		$(MAKE) --no-print-directory build-module MODULE=$$mod; \
	done

run: test

test tests:
	@set -e; \
	if [[ -n "$(MODULE)" ]]; then \
		if [[ ! -f "$(TB_DIR)/$(MODULE)_tb.sv" ]]; then \
			echo "Testbench not found: $(TB_DIR)/$(MODULE)_tb.sv"; \
			echo "Available modules: $(MODULES)"; \
			exit 1; \
		fi; \
		$(MAKE) --no-print-directory run-module MODULE=$(MODULE); \
	else \
		if [[ -z "$(MODULES)" ]]; then \
			echo "No testbenches found in $(TB_DIR). Expected files like <module>_tb.sv"; \
			exit 1; \
		fi; \
		for mod in $(MODULES); do \
			$(MAKE) --no-print-directory run-module MODULE=$$mod; \
		done; \
	fi

build-module:
	@if [[ -z "$(MODULE)" ]]; then \
		echo "MODULE is required. Example: make build-module MODULE=pe"; \
		exit 1; \
	fi
	@if [[ ! -f "$(TB_DIR)/$(MODULE)_tb.sv" ]]; then \
		echo "Testbench not found: $(TB_DIR)/$(MODULE)_tb.sv"; \
		exit 1; \
	fi
	@mkdir -p $(SIM_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module $(MODULE)_tb \
		--Mdir $(SIM_DIR)/$(MODULE)_obj \
		$(RTL_SOURCES) $(TB_DIR)/$(MODULE)_tb.sv \
		-o $(MODULE)_sim

run-module: build-module
	./$(SIM_DIR)/$(MODULE)_obj/$(MODULE)_sim

clean:
	rm -rf $(SIM_DIR)/*
	rm -f *.vcd *.fst

# Swallow the extra goal in: make test <module>
%:
	@:
