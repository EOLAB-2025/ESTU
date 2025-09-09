filename   := soc
pcf_file   := rtl/icebreaker.pcf
JSON_FILE  := output/$(filename).json
BLIF_FILE  := output/$(filename).blif
ASC_FILE   := output/$(filename).asc
BIN_FILE   := output/$(filename).bin
YOSYS_LOG  := logs/yosys.log
PNR_LOG    := logs/nextpnr.log
RTL_SRCS = rtl/define.v rtl/estu/top/*.v rtl/estu/mmu/*.v rtl/estu/datapath/*.v rtl/servant/*.v rtl/serv/*.v

YOSYS_SRCS := rtl/define.v \
               $(wildcard rtl/estu/top/*.v) \
               $(wildcard rtl/estu/*.v) \
			   $(wildcard rtl/estu/datapath/*.v) \
               $(wildcard rtl/estu/mmu/*.v)

env:
	cd ../ && source oss-cad-suite/environment

build: 
	yosys -p "synth_ice40 -dsp -abc9 -top soc -json output/$(filename).json -blif output/$(filename).blif -flatten" $(RTL_SRCS) -l output/yosys.log
	nextpnr-ice40 --up5k --package sg48 --json output/$(filename).json --pcf $(pcf_file) --asc output/$(filename).asc --seed 90 -l output/nextpnr.log -v
	icepack output/$(filename).asc output/$(filename).bin -s

build-best:
	@mkdir -p logs output/best
	@rm -f output/best_freq.txt
	yosys -p "synth_ice40 -dsp -abc9 -top soc -json output/$(filename).json -flatten" $(RTL_SRCS) -l output/yosys.log
	@echo "Seed | Fmax (MHz)" > output/best_freq.txt
	@for SEED in $$(seq 1 100); do \
		echo ">>> Trying seed $$SEED..."; \
		nextpnr-ice40 --up5k --package sg48 \
			--json output/$(filename).json \
			--pcf  $(pcf_file) \
			--asc  output/best/$(filename)_seed$$SEED.asc \
			--threads $$(nproc) --freq 24 \
			--seed $$SEED --timing-allow-fail \
			> logs/nextpnr_seed$$SEED.log 2>&1; \
		FREQ=$$(grep "Max frequency for clock  'servant.wb_clk'" logs/nextpnr_seed$$SEED.log | \
		sed -nE 's/.*clock[[:space:]]+'\''servant\.wb_clk'\''.*: ([0-9]+\.[0-9]+) MHz.*/\1/p'); \
		[ -z "$$FREQ" ] && FREQ="0.00"; \
		echo "$$SEED | $$FREQ" >> output/best_freq.txt; \
	done; \
	sort -nr -k3 -t'|' output/best_freq.txt | head -n 2 > output/best/best_seed.txt; \
	BEST_SEED=$$(head -n1 output/best/best_seed.txt | cut -d '|' -f1 | tr -d ' '); \
	cp output/best/$(filename)_seed$$BEST_SEED.asc output/$(filename).asc; \
	echo "==> Best seed: $$BEST_SEED"
	icepack output/$(filename).asc output/$(filename).bin -s

check_json:
	yosys -p "read_json output/$(filename).json; proc; opt; opt_clean; check"


prog:
	sudo iceprog output/$(filename).bin

 simulate:
	#cd firmware && make -B
	iverilog -o rtl_sim -DSIMULATION $(VFLAGS) sim/tb/tb_soc.v sim/tb/flash_spi_sim.sv sim/tb/uart_decoder.v $(RTL_SRCS) sim/tb/SB_LFOSC.v sim/tb/SB_HFOSC.v
	vvp rtl_sim
	rm rtl_sim 
	mv tb_soc.vcd work/
	gtkwave --save=work/tb_soc.gtkw work/tb_soc.vcd &

LOG_DIR    := logs
WORK_DIR   := work
RTL_DIR    := rtl
SIM_TB_DIR := sim/tb

# testbench and source files
TB      := $(SIM_TB_DIR)/tb_estu.sv
SOURCES := $(shell find $(RTL_DIR) -type f \( -name '*.sv' -o -name '*.v' \)) $(TB)
VVP_OUT := tb_estu.vvp
VCD_OUT := $(WORK_DIR)/tb_estu.vcd

# Clean only logs and intermediate files
clean-logs:
	@echo "[SIM] Cleaning logs and generated files..."
	@rm -f $(LOG_DIR)/*.log
	@rm -f $(VVP_OUT)
	@rm -f $(VCD_OUT)

# Clean everything (logs + .vvp + .vcd)
clean: clean-logs
	@echo "[SIM] Clean complete!"

$(LOG_DIR)/iverilog.log: $(SOURCES)
	@mkdir -p $(LOG_DIR) $(WORK_DIR)
	@echo "[SIM] Compiling → $@"
	iverilog -g2012 -DSIMULATION -o $(VVP_OUT) \
	  -I$(RTL_DIR) -I$(RTL_DIR)/estu/include -I$(SIM_TB_DIR) \
	  $(SOURCES) \
	2>&1 | tee $@

$(LOG_DIR)/vvp.log: $(LOG_DIR)/iverilog.log
	@echo "[SIM] Simulating → $@"
	vvp $(VVP_OUT) 2>&1 | tee $@
	@mv tb_estu.vcd $(VCD_OUT) 2>/dev/null || true

psimulate: 
	yosys -p 'read_blif -wideports output/soc.blif; write_verilog output/top_syn.v'
	iverilog -g2012 -o gate_sim rtl/psim.v rtl/define.v sim/tb/tb_soc_psim.v sim/tb/flash_spi_sim.sv sim/tb/uart_decoder.v output/top_syn.v sim/tb/cells_sim.v sim/tb/SB_LFOSC.v sim/tb/SB_HFOSC.v
	vvp gate_sim
	rm gate_sim 
	mv tb_soc_psim.vcd work/
	gtkwave --save=work/ps_serv_waves.gtkw work/tb_soc_psim.vcd &

listen:
	sudo rm output/serial.txt || true
	sudo minicom -b 3000000 -D /dev/ttyUSB1 -H -C output/serial.txt


#clean:
#	rm -f *.vcd 
#	rm -f rtl_sim
#	rm -f gate_sim
#	rm -f work/*.vcd




