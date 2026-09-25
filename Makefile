ACME ?= acme
VICE ?= x64sc
BUILD_DIR := build
PRG := $(BUILD_DIR)/c64-matrix-screensaver.prg
SOURCE := src/matrix_screensaver.s

.PHONY: audit build run clean

audit:
	python3 tools/static_audit.py $(SOURCE)

build: audit
	mkdir -p $(BUILD_DIR)
	$(ACME) -f cbm -o $(PRG) $(SOURCE)

run: build
	$(VICE) -autostartprgmode 1 -autostart $(PRG)

clean:
	rm -rf $(BUILD_DIR)
