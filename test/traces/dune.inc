; Written by write_trace.exe -dune, a pair of rules a scenario.

(rule
 (with-stdout-to
  uart_tx.trace.gen
  (run ./write_trace.exe uart_tx)))

(rule
 (alias runtest)
 (action
  (diff uart_tx.trace uart_tx.trace.gen)))

(rule
 (with-stdout-to
  uart_rx.trace.gen
  (run ./write_trace.exe uart_rx)))

(rule
 (alias runtest)
 (action
  (diff uart_rx.trace uart_rx.trace.gen)))

(rule
 (with-stdout-to
  spi_master.trace.gen
  (run ./write_trace.exe spi_master)))

(rule
 (alias runtest)
 (action
  (diff spi_master.trace spi_master.trace.gen)))

(rule
 (with-stdout-to
  i2c_logger.trace.gen
  (run ./write_trace.exe i2c_logger)))

(rule
 (alias runtest)
 (action
  (diff i2c_logger.trace i2c_logger.trace.gen)))

(rule
 (with-stdout-to
  snorble.trace.gen
  (run ./write_trace.exe snorble)))

(rule
 (alias runtest)
 (action
  (diff snorble.trace snorble.trace.gen)))

(rule
 (with-stdout-to
  plinkoo.trace.gen
  (run ./write_trace.exe plinkoo)))

(rule
 (alias runtest)
 (action
  (diff plinkoo.trace plinkoo.trace.gen)))

(rule
 (with-stdout-to
  frumbleglide.trace.gen
  (run ./write_trace.exe frumbleglide)))

(rule
 (alias runtest)
 (action
  (diff frumbleglide.trace frumbleglide.trace.gen)))

(rule
 (with-stdout-to
  microwire.trace.gen
  (run ./write_trace.exe microwire)))

(rule
 (alias runtest)
 (action
  (diff microwire.trace microwire.trace.gen)))

(rule
 (with-stdout-to
  caliper.trace.gen
  (run ./write_trace.exe caliper)))

(rule
 (alias runtest)
 (action
  (diff caliper.trace caliper.trace.gen)))

(rule
 (with-stdout-to
  xy2_100.trace.gen
  (run ./write_trace.exe xy2_100)))

(rule
 (alias runtest)
 (action
  (diff xy2_100.trace xy2_100.trace.gen)))

(rule
 (with-stdout-to
  lfast.trace.gen
  (run ./write_trace.exe lfast)))

(rule
 (alias runtest)
 (action
  (diff lfast.trace lfast.trace.gen)))

(rule
 (with-stdout-to
  tdm_audio.trace.gen
  (run ./write_trace.exe tdm_audio)))

(rule
 (alias runtest)
 (action
  (diff tdm_audio.trace tdm_audio.trace.gen)))

(rule
 (with-stdout-to
  dali.trace.gen
  (run ./write_trace.exe dali)))

(rule
 (alias runtest)
 (action
  (diff dali.trace dali.trace.gen)))

(rule
 (with-stdout-to
  lin.trace.gen
  (run ./write_trace.exe lin)))

(rule
 (alias runtest)
 (action
  (diff lin.trace lin.trace.gen)))

(rule
 (with-stdout-to
  spdif.trace.gen
  (run ./write_trace.exe spdif)))

(rule
 (alias runtest)
 (action
  (diff spdif.trace spdif.trace.gen)))

(rule
 (with-stdout-to
  usb_power_delivery.trace.gen
  (run ./write_trace.exe usb_power_delivery)))

(rule
 (alias runtest)
 (action
  (diff usb_power_delivery.trace usb_power_delivery.trace.gen)))

(rule
 (with-stdout-to
  dmx512.trace.gen
  (run ./write_trace.exe dmx512)))

(rule
 (alias runtest)
 (action
  (diff dmx512.trace dmx512.trace.gen)))

(rule
 (with-stdout-to
  wiegand.trace.gen
  (run ./write_trace.exe wiegand)))

(rule
 (alias runtest)
 (action
  (diff wiegand.trace wiegand.trace.gen)))

(rule
 (with-stdout-to
  swd_blind.trace.gen
  (run ./write_trace.exe swd_blind)))

(rule
 (alias runtest)
 (action
  (diff swd_blind.trace swd_blind.trace.gen)))

(rule
 (with-stdout-to
  ir_nec.trace.gen
  (run ./write_trace.exe ir_nec)))

(rule
 (alias runtest)
 (action
  (diff ir_nec.trace ir_nec.trace.gen)))

(rule
 (with-stdout-to
  tlc5620.trace.gen
  (run ./write_trace.exe tlc5620)))

(rule
 (alias runtest)
 (action
  (diff tlc5620.trace tlc5620.trace.gen)))

(rule
 (with-stdout-to
  wrapped_loop.trace.gen
  (run ./write_trace.exe wrapped_loop)))

(rule
 (alias runtest)
 (action
  (diff wrapped_loop.trace wrapped_loop.trace.gen)))

(rule
 (with-stdout-to
  fifo_poll.trace.gen
  (run ./write_trace.exe fifo_poll)))

(rule
 (alias runtest)
 (action
  (diff fifo_poll.trace fifo_poll.trace.gen)))

(rule
 (with-stdout-to
  bridge.trace.gen
  (run ./write_trace.exe bridge)))

(rule
 (alias runtest)
 (action
  (diff bridge.trace bridge.trace.gen)))
