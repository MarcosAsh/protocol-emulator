all: issue_timing host_timing fifo_order teeth

engine.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine > formal/engine.v

engine_sram.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine -sram > formal/engine_sram.v

issue_timing: engine.v
	sby -f issue_timing.sby prove cover

host_timing: engine_sram.v
	sby -f host_timing.sby prove

fifo_order: engine.v
	sby -f fifo_order.sby prove cover

# weakened statements, which pass only by failing
teeth: engine.v engine_sram.v
	sby -f issue_timing.sby jump_in_one delay_ignores_side_set waits_are_plain
	sby -f fifo_order.sby stale_ahead
	sby -f host_timing.sby private_pull no_wait_excuse no_jump_excuse no_underflow_excuse no_overflow_excuse

# Each firmware's certificate from the analyser, as properties of the RTL for every input
# and every host, to the depth in certificate.sby. The cover run says how far into the
# firmware that depth reaches: a row it does not reach is not proven of that row, which is
# why the reached ones are printed. Only the properties failing is a failure here.
CERTIFIED = uart_tx spi_master ws2812
certificates: engine.v
	for name in $(CERTIFIED); do $(MAKE) certificate NAME=$$name || exit 1; done

# One firmware, at the depth in SBY. A firmware slow enough to need more than the depth
# certificate.sby carries is run on its own, which takes the better part of an hour:
#   make certificate NAME=uart_tx16 SBY=deep_certificate.sby
SBY = certificate.sby
certificate: engine.v
	(cd .. && dune exec -- test/certify/write_certificate.exe $(NAME)) > certificate.sv
	sby -f -d certificate_$(NAME)_bmc $(SBY) bmc
	-sby -f -d certificate_$(NAME)_cover $(SBY) cover
	@rows=$$(grep -c 'cover (entry' certificate.sv); \
	 missed=$$(grep -A99 'unreached cover statements' certificate_$(NAME)_cover/logfile.txt \
	   | grep -c 'certificate.sv:'); \
	 echo "$(NAME): $$((rows - missed)) of $$rows certified rows reached at this depth"

# The certificate of one firmware as an invariant proved by induction, which holds for
# all time and not only to a depth: make inductive_certificate NAME=uart_tx16. The teeth
# run adds one claim that is false in any run, because induction proves anything from an
# invariant no state satisfies, so it has to fail.
inductive_certificate: engine_sram.v
	(cd .. && dune exec -- test/certify/write_certificate.exe -inductive $(NAME)) > certificate.sv
	sby -f -d certificate_$(NAME)_inductive certificate_inductive.sby prove
	sby -f -d certificate_$(NAME)_teeth certificate_inductive.sby teeth

# Every firmware in test/certified.ml, each under what its entry there says it assumes,
# which the certificate prints: nothing for most; for ws2812, whose reset gap is a loop
# anchoring no deadline, and for the firmware that waits on the host or anchors on a
# captured edge, that the core is within 84 ms of its deadline and of that edge, since
# 24 bits of the difference wrap beyond it.
INDUCTIVE = uart_tx uart_tx16 uart_tx_host_rate uart_rx spi_master spi_slave i2c_master \
  i2c_slave i2c_logger usb_tx usb_rx usb_device edge_meter ws2812 ethernet one_wire ps2 jtag
inductive_certificates: engine_sram.v
	for name in $(INDUCTIVE); do $(MAKE) inductive_certificate NAME=$$name || exit 1; done

.PHONY: all issue_timing host_timing fifo_order teeth certificates certificate \
  inductive_certificate inductive_certificates
