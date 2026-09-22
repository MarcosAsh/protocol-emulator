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
ASSUME =
inductive_certificate: engine_sram.v
	(cd .. && dune exec -- test/certify/write_certificate.exe -inductive $(ASSUME) $(NAME)) > certificate.sv
	sby -f -d certificate_$(NAME)_inductive certificate_inductive.sby prove
	sby -f -d certificate_$(NAME)_teeth certificate_inductive.sby teeth

# The firmware whose certificates close as an invariant, which rests on nothing at all,
# and the firmware that needs the one assumption: ws2812's reset gap is a loop anchoring
# no deadline, so the analyser leaves its phase without a floor and 24 bits of it wrap.
INDUCTIVE = uart_tx uart_tx16 spi_master
INDUCTIVE_ASSUMING_NO_WRAP = ws2812
inductive_certificates: engine_sram.v
	for name in $(INDUCTIVE); do $(MAKE) inductive_certificate NAME=$$name || exit 1; done
	for name in $(INDUCTIVE_ASSUMING_NO_WRAP); do \
	  $(MAKE) inductive_certificate NAME=$$name ASSUME=-no-wrap || exit 1; \
	done

.PHONY: all issue_timing host_timing fifo_order teeth certificates certificate \
  inductive_certificate inductive_certificates
