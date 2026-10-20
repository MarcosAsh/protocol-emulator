open! Core

let i2c_short_start =
  let bench = Library.find_bench_exn "i2c_standard" in
  { bench with source = I2c.master_host_rate_held ~quarters:1 () }
;;

let ws2812_short_bit =
  let bench = Library.find_bench_exn "sk6812" in
  let gaps = (Bench.cycles_in ~us:200 / (160 * 17)) + 1 in
  { bench with source = Ws2812.latching ~gaps ~third:17 ~tail:5 }
;;
