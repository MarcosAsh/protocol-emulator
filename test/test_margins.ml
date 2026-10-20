open! Core

let%expect_test "every point" =
  List.iter (Margins.all ()) ~f:(fun (sweep : Margins.Sweep.t) ->
    printf "%s %s\n" sweep.part sweep.parameter;
    List.iter sweep.points ~f:(function
      | Second why -> printf "  %s\n" why
      | First (p : Margins.Point.t) ->
        printf
          "  %5d %-9s designed %s sweep %b  %s\n"
          p.cycles
          (Bench.time p.cycles)
          (Option.value_map p.designed ~default:"-" ~f:Int.to_string)
          p.sweep_ok
          (Margins.Point.label p)));
  [%expect
    {|
    SK6812 T0H
      42 ns: the kernel refuses it, line 48: this deadline wait can be reached 3 cycles late (slack -3)
      62 ns: the kernel refuses it, line 48: this deadline wait can be reached 2 cycles late (slack -2)
      83 ns: the kernel refuses it, line 48: this deadline wait can be reached 1 cycle late (slack -1)
      104 ns: the kernel refuses it, line 54: this deadline wait can be reached 3 cycles late (slack -3)
      125 ns: the kernel refuses it, line 54: this deadline wait can be reached 2 cycles late (slack -2)
      146 ns: the kernel refuses it, line 54: this deadline wait can be reached 1 cycle late (slack -1)
      167 ns: the kernel refuses it, line 55: this deadline wait can be reached 1 cycle late (slack -1)
          9 188 ns    designed 9 sweep true  OUT OF SPEC: T0H 188 ns (sheet >= 250 ns + a cycle)
         10 208 ns    designed 10 sweep true  OUT OF SPEC: T0H 208 ns (sheet >= 250 ns + a cycle)
         11 229 ns    designed 11 sweep true  OUT OF SPEC: T0H 229 ns (sheet >= 250 ns + a cycle)
         12 250 ns    designed 12 sweep true  OUT OF SPEC: T0H 250 ns (sheet >= 250 ns + a cycle)
         13 271 ns    designed 13 sweep true  in spec
         14 292 ns    designed 14 sweep true  in spec
         15 312 ns    designed 15 sweep true  in spec
         16 333 ns    designed 16 sweep true  in spec
         17 354 ns    designed 17 sweep true  in spec
         18 375 ns    designed 18 sweep true  in spec
         19 396 ns    designed 19 sweep true  OUT OF SPEC: T0H 396 ns (sheet <= 400 ns + a cycle)
         20 417 ns    designed 20 sweep true  OUT OF SPEC: T0H 417 ns (sheet <= 400 ns + a cycle)
         21 438 ns    designed 21 sweep true  OUT OF SPEC: T0H 438 ns (sheet <= 400 ns + a cycle)
         22 458 ns    designed 22 sweep true  OUT OF SPEC: T0H 458 ns (sheet <= 400 ns + a cycle)
         23 479 ns    designed 23 sweep true  OUT OF SPEC: T0H 479 ns (sheet <= 400 ns + a cycle)
         24 500 ns    designed 24 sweep true  OUT OF SPEC: T0H 500 ns (sheet <= 400 ns + a cycle)
         25 521 ns    designed 25 sweep true  OUT OF SPEC: T0H 521 ns (sheet <= 400 ns + a cycle)
         26 542 ns    designed 26 sweep true  OUT OF SPEC: T0H 542 ns (sheet <= 400 ns + a cycle)
         27 562 ns    designed 27 sweep true  OUT OF SPEC: T0H 562 ns (sheet <= 400 ns + a cycle)
         28 583 ns    designed 28 sweep true  OUT OF SPEC: T0H 583 ns (sheet <= 400 ns + a cycle)
         29 604 ns    designed 29 sweep true  OUT OF SPEC: T0H 604 ns (sheet <= 400 ns + a cycle)
         30 625 ns    designed 30 sweep true  OUT OF SPEC: T0H 625 ns (sheet <= 400 ns + a cycle)
         31 646 ns    designed 31 sweep true  OUT OF SPEC: T0H 646 ns (sheet <= 400 ns + a cycle)
         32 667 ns    designed 32 sweep true  OUT OF SPEC: T0H 667 ns (sheet <= 400 ns + a cycle)
         33 688 ns    designed 33 sweep true  OUT OF SPEC: T0H 688 ns (sheet <= 400 ns + a cycle)
         34 708 ns    designed 34 sweep true  OUT OF SPEC: T0H 708 ns (sheet <= 400 ns + a cycle)
         35 729 ns    designed 35 sweep true  OUT OF SPEC: T0H 729 ns (sheet <= 400 ns + a cycle)
         36 750 ns    designed 36 sweep true  OUT OF SPEC: T0H 750 ns (sheet <= 400 ns + a cycle)
         37 771 ns    designed 37 sweep true  OUT OF SPEC: T0H 771 ns (sheet <= 400 ns + a cycle)
         38 792 ns    designed 38 sweep true  OUT OF SPEC: T0H 792 ns (sheet <= 400 ns + a cycle)
         39 812 ns    designed 39 sweep true  OUT OF SPEC: T0H 812 ns (sheet <= 400 ns + a cycle)
         40 833 ns    designed 40 sweep true  OUT OF SPEC: T0H 833 ns (sheet <= 400 ns + a cycle)
         44 917 ns    designed 44 sweep true  OUT OF SPEC: T0H 917 ns (sheet <= 400 ns + a cycle)
         48 1 us      designed 48 sweep true  OUT OF SPEC: T0H 1 us (sheet <= 400 ns + a cycle)
         56 1.167 us  designed 56 sweep true  OUT OF SPEC: T0H 1.167 us (sheet <= 400 ns + a cycle)
    SK6812 T1H
      42 ns: the kernel refuses it, line 21: this deadline wait can be reached 3 cycles late (slack -3)
      62 ns: the kernel refuses it, line 21: this deadline wait can be reached 2 cycles late (slack -2)
      83 ns: the kernel refuses it, line 21: this deadline wait can be reached 1 cycle late (slack -1)
      104 ns: the kernel refuses it, line 27: this deadline wait can be reached 3 cycles late (slack -3)
      125 ns: the kernel refuses it, line 27: this deadline wait can be reached 2 cycles late (slack -2)
      146 ns: the kernel refuses it, line 27: this deadline wait can be reached 1 cycle late (slack -1)
      167 ns: the kernel refuses it, line 28: this deadline wait can be reached 1 cycle late (slack -1)
          9 188 ns    designed 9 sweep true  OUT OF SPEC: T1H 188 ns (sheet >= 650 ns + a cycle)
         10 208 ns    designed 10 sweep true  OUT OF SPEC: T1H 208 ns (sheet >= 650 ns + a cycle)
         11 229 ns    designed 11 sweep true  OUT OF SPEC: T1H 229 ns (sheet >= 650 ns + a cycle)
         12 250 ns    designed 12 sweep true  OUT OF SPEC: T1H 250 ns (sheet >= 650 ns + a cycle)
         13 271 ns    designed 13 sweep true  OUT OF SPEC: T1H 271 ns (sheet >= 650 ns + a cycle)
         14 292 ns    designed 14 sweep true  OUT OF SPEC: T1H 292 ns (sheet >= 650 ns + a cycle)
         15 312 ns    designed 15 sweep true  OUT OF SPEC: T1H 312 ns (sheet >= 650 ns + a cycle)
         16 333 ns    designed 16 sweep true  OUT OF SPEC: T1H 333 ns (sheet >= 650 ns + a cycle)
         17 354 ns    designed 17 sweep true  OUT OF SPEC: T1H 354 ns (sheet >= 650 ns + a cycle)
         18 375 ns    designed 18 sweep true  OUT OF SPEC: T1H 375 ns (sheet >= 650 ns + a cycle)
         19 396 ns    designed 19 sweep true  OUT OF SPEC: T1H 396 ns (sheet >= 650 ns + a cycle)
         20 417 ns    designed 20 sweep true  OUT OF SPEC: T1H 417 ns (sheet >= 650 ns + a cycle)
         21 438 ns    designed 21 sweep true  OUT OF SPEC: T1H 438 ns (sheet >= 650 ns + a cycle)
         22 458 ns    designed 22 sweep true  OUT OF SPEC: T1H 458 ns (sheet >= 650 ns + a cycle)
         23 479 ns    designed 23 sweep true  OUT OF SPEC: T1H 479 ns (sheet >= 650 ns + a cycle)
         24 500 ns    designed 24 sweep true  OUT OF SPEC: T1H 500 ns (sheet >= 650 ns + a cycle)
         25 521 ns    designed 25 sweep true  OUT OF SPEC: T1H 521 ns (sheet >= 650 ns + a cycle)
         26 542 ns    designed 26 sweep true  OUT OF SPEC: T1H 542 ns (sheet >= 650 ns + a cycle)
         27 562 ns    designed 27 sweep true  OUT OF SPEC: T1H 562 ns (sheet >= 650 ns + a cycle)
         28 583 ns    designed 28 sweep true  OUT OF SPEC: T1H 583 ns (sheet >= 650 ns + a cycle)
         29 604 ns    designed 29 sweep true  OUT OF SPEC: T1H 604 ns (sheet >= 650 ns + a cycle)
         30 625 ns    designed 30 sweep true  OUT OF SPEC: T1H 625 ns (sheet >= 650 ns + a cycle)
         31 646 ns    designed 31 sweep true  OUT OF SPEC: T1H 646 ns (sheet >= 650 ns + a cycle)
         32 667 ns    designed 32 sweep true  OUT OF SPEC: T1H 667 ns (sheet >= 650 ns + a cycle)
         33 688 ns    designed 33 sweep true  in spec
         34 708 ns    designed 34 sweep true  in spec
         35 729 ns    designed 35 sweep true  in spec
         36 750 ns    designed 36 sweep true  in spec
         37 771 ns    designed 37 sweep true  in spec
         38 792 ns    designed 38 sweep true  in spec
         39 812 ns    designed 39 sweep true  in spec
         40 833 ns    designed 40 sweep true  in spec
         44 917 ns    designed 44 sweep true  in spec
         48 1 us      designed 48 sweep true  OUT OF SPEC: T1H 1 us (sheet <= 1 us + a cycle)
         56 1.167 us  designed 56 sweep true  OUT OF SPEC: T1H 1.167 us (sheet <= 1 us + a cycle)
         64 1.333 us  designed 64 sweep true  OUT OF SPEC: T1H 1.333 us (sheet <= 1 us + a cycle)
         80 1.667 us  designed 80 sweep true  OUT OF SPEC: T1H 1.667 us (sheet <= 1 us + a cycle)
         96 2 us      designed 96 sweep true  OUT OF SPEC: T1H 2 us (sheet <= 1 us + a cycle)
        120 2.5 us    designed 120 sweep true  OUT OF SPEC: T1H 2.5 us (sheet <= 1 us + a cycle)
        160 3.333 us  designed 160 sweep true  OUT OF SPEC: T1H 3.333 us (sheet <= 1 us + a cycle)
        240 5 us      designed 240 sweep true  OUT OF SPEC: T1H 5 us (sheet <= 1 us + a cycle)
        480 10 us     designed 480 sweep true  OUT OF SPEC: T1H 10 us (sheet <= 1 us + a cycle)
    SK6812 T0L
      42 ns: the kernel refuses it, line 17: this deadline wait can be reached 3 cycles late (slack -3..17)
      62 ns: the kernel refuses it, line 17: this deadline wait can be reached 2 cycles late (slack -2..17)
      83 ns: the kernel refuses it, line 17: this deadline wait can be reached 1 cycle late (slack -1..17)
          5 104 ns    designed 5 sweep true  OUT OF SPEC: T0L 104 ns (sheet >= 800 ns + a cycle), T 458 ns (sheet >= 1.2 us + a cycle)
          6 125 ns    designed 6 sweep true  OUT OF SPEC: T0L 125 ns (sheet >= 800 ns + a cycle), T 479 ns (sheet >= 1.2 us + a cycle)
          7 146 ns    designed 7 sweep true  OUT OF SPEC: T0L 146 ns (sheet >= 800 ns + a cycle), T 500 ns (sheet >= 1.2 us + a cycle)
          8 167 ns    designed 8 sweep true  OUT OF SPEC: T0L 167 ns (sheet >= 800 ns + a cycle), T 521 ns (sheet >= 1.2 us + a cycle)
          9 188 ns    designed 9 sweep true  OUT OF SPEC: T0L 188 ns (sheet >= 800 ns + a cycle), T 542 ns (sheet >= 1.2 us + a cycle)
         10 208 ns    designed 10 sweep true  OUT OF SPEC: T0L 208 ns (sheet >= 800 ns + a cycle), T 562 ns (sheet >= 1.2 us + a cycle)
         11 229 ns    designed 11 sweep true  OUT OF SPEC: T0L 229 ns (sheet >= 800 ns + a cycle), T 583 ns (sheet >= 1.2 us + a cycle)
         12 250 ns    designed 12 sweep true  OUT OF SPEC: T0L 250 ns (sheet >= 800 ns + a cycle), T 604 ns (sheet >= 1.2 us + a cycle)
         13 271 ns    designed 13 sweep true  OUT OF SPEC: T0L 271 ns (sheet >= 800 ns + a cycle), T 625 ns (sheet >= 1.2 us + a cycle)
         14 292 ns    designed 14 sweep true  OUT OF SPEC: T0L 292 ns (sheet >= 800 ns + a cycle), T 646 ns (sheet >= 1.2 us + a cycle)
         15 312 ns    designed 15 sweep true  OUT OF SPEC: T0L 312 ns (sheet >= 800 ns + a cycle), T 667 ns (sheet >= 1.2 us + a cycle)
         16 333 ns    designed 16 sweep true  OUT OF SPEC: T0L 333 ns (sheet >= 800 ns + a cycle), T 688 ns (sheet >= 1.2 us + a cycle)
         17 354 ns    designed 17 sweep true  OUT OF SPEC: T0L 354 ns (sheet >= 800 ns + a cycle), T 708 ns (sheet >= 1.2 us + a cycle)
         18 375 ns    designed 18 sweep true  OUT OF SPEC: T0L 375 ns (sheet >= 800 ns + a cycle), T 729 ns (sheet >= 1.2 us + a cycle)
         19 396 ns    designed 19 sweep true  OUT OF SPEC: T0L 396 ns (sheet >= 800 ns + a cycle), T 750 ns (sheet >= 1.2 us + a cycle)
         20 417 ns    designed 20 sweep true  OUT OF SPEC: T0L 417 ns (sheet >= 800 ns + a cycle), T 771 ns (sheet >= 1.2 us + a cycle)
         21 438 ns    designed 21 sweep true  OUT OF SPEC: T0L 438 ns (sheet >= 800 ns + a cycle), T 792 ns (sheet >= 1.2 us + a cycle)
         22 458 ns    designed 22 sweep true  OUT OF SPEC: T0L 458 ns (sheet >= 800 ns + a cycle), T 812 ns (sheet >= 1.2 us + a cycle)
         23 479 ns    designed 23 sweep true  OUT OF SPEC: T0L 479 ns (sheet >= 800 ns + a cycle), T 833 ns (sheet >= 1.2 us + a cycle)
         24 500 ns    designed 24 sweep true  OUT OF SPEC: T0L 500 ns (sheet >= 800 ns + a cycle), T 854 ns (sheet >= 1.2 us + a cycle)
         25 521 ns    designed 25 sweep true  OUT OF SPEC: T0L 521 ns (sheet >= 800 ns + a cycle), T 875 ns (sheet >= 1.2 us + a cycle)
         26 542 ns    designed 26 sweep true  OUT OF SPEC: T0L 542 ns (sheet >= 800 ns + a cycle), T 896 ns (sheet >= 1.2 us + a cycle)
         27 562 ns    designed 27 sweep true  OUT OF SPEC: T0L 562 ns (sheet >= 800 ns + a cycle), T 917 ns (sheet >= 1.2 us + a cycle)
         28 583 ns    designed 28 sweep true  OUT OF SPEC: T0L 583 ns (sheet >= 800 ns + a cycle), T 938 ns (sheet >= 1.2 us + a cycle)
         29 604 ns    designed 29 sweep true  OUT OF SPEC: T0L 604 ns (sheet >= 800 ns + a cycle), T 958 ns (sheet >= 1.2 us + a cycle)
         30 625 ns    designed 30 sweep true  OUT OF SPEC: T0L 625 ns (sheet >= 800 ns + a cycle), T 979 ns (sheet >= 1.2 us + a cycle)
         31 646 ns    designed 31 sweep true  OUT OF SPEC: T0L 646 ns (sheet >= 800 ns + a cycle), T 1 us (sheet >= 1.2 us + a cycle)
         32 667 ns    designed 32 sweep true  OUT OF SPEC: T0L 667 ns (sheet >= 800 ns + a cycle), T 1.021 us (sheet >= 1.2 us + a cycle)
         33 688 ns    designed 33 sweep true  OUT OF SPEC: T0L 688 ns (sheet >= 800 ns + a cycle), T 1.042 us (sheet >= 1.2 us + a cycle)
         34 708 ns    designed 34 sweep true  OUT OF SPEC: T0L 708 ns (sheet >= 800 ns + a cycle), T 1.062 us (sheet >= 1.2 us + a cycle)
         35 729 ns    designed 35 sweep true  OUT OF SPEC: T0L 729 ns (sheet >= 800 ns + a cycle), T 1.083 us (sheet >= 1.2 us + a cycle)
         36 750 ns    designed 36 sweep true  OUT OF SPEC: T0L 750 ns (sheet >= 800 ns + a cycle), T 1.104 us (sheet >= 1.2 us + a cycle)
         37 771 ns    designed 37 sweep true  OUT OF SPEC: T0L 771 ns (sheet >= 800 ns + a cycle), T 1.125 us (sheet >= 1.2 us + a cycle)
         38 792 ns    designed 38 sweep true  OUT OF SPEC: T0L 792 ns (sheet >= 800 ns + a cycle), T 1.146 us (sheet >= 1.2 us + a cycle)
         39 812 ns    designed 39 sweep true  OUT OF SPEC: T0L 812 ns (sheet >= 800 ns + a cycle), T 1.167 us (sheet >= 1.2 us + a cycle)
         40 833 ns    designed 40 sweep true  OUT OF SPEC: T 1.188 us (sheet >= 1.2 us + a cycle)
         41 854 ns    designed 41 sweep true  OUT OF SPEC: T 1.208 us (sheet >= 1.2 us + a cycle)
         42 875 ns    designed 42 sweep true  in spec
         43 896 ns    designed 43 sweep true  in spec
         44 917 ns    designed 44 sweep true  in spec
         45 938 ns    designed 45 sweep true  in spec
         46 958 ns    designed 46 sweep true  in spec
         47 979 ns    designed 47 sweep true  in spec
         48 1 us      designed 48 sweep true  in spec
         72 1.5 us    designed 72 sweep true  in spec
         96 2 us      designed 96 sweep true  in spec
        144 3 us      designed 144 sweep true  in spec
        192 4 us      designed 192 sweep true  in spec
        240 5 us      designed 240 sweep true  in spec
        288 6 us      designed 288 sweep true  in spec
        336 7 us      designed 336 sweep true  in spec
        384 8 us      designed 384 sweep true  in spec
        480 10 us     designed 480 sweep true  in spec
        576 12 us     designed 576 sweep true  in spec
        720 15 us     designed 720 sweep true  in spec
        960 20 us     designed 960 sweep true  OUT OF SPEC: T0L 20 us (sheet <= 20 us + a cycle)
       1200 25 us     designed 1200 sweep true  OUT OF SPEC: T0L 25 us (sheet <= 20 us + a cycle)
       1440 30 us     designed 1440 sweep true  OUT OF SPEC: T0L 30 us (sheet <= 20 us + a cycle)
       1920 40 us     designed 1920 sweep true  OUT OF SPEC: T0L 40 us (sheet <= 20 us + a cycle)
       2400 50 us     designed 2400 sweep true  OUT OF SPEC: T0L 50 us (sheet <= 20 us + a cycle)
       2880 60 us     designed 2880 sweep true  OUT OF SPEC: T0L 60 us (sheet <= 20 us + a cycle)
       3360 70 us     designed 3360 sweep true  OUT OF SPEC: T0L 70 us (sheet <= 20 us + a cycle)
       3840 80 us     designed 3840 sweep true  OUT OF SPEC: T0L 80 us (sheet <= 20 us + a cycle)
       4320 90 us     designed 4320 sweep true  OUT OF SPEC: T0L 90 us (sheet <= 20 us + a cycle)
       4800 100 us    designed 4800 sweep true  OUT OF SPEC: T0L 100 us (sheet <= 20 us + a cycle)
       5280 110 us    designed 5280 sweep true  OUT OF SPEC: T0L 110 us (sheet <= 20 us + a cycle)
       5760 120 us    designed 5760 sweep true  OUT OF SPEC: T0L 120 us (sheet <= 20 us + a cycle)
    SK6812 T1L
      42 ns: the kernel refuses it, line 17: this deadline wait can be reached 3 cycles late (slack -3..35)
      62 ns: the kernel refuses it, line 17: this deadline wait can be reached 2 cycles late (slack -2..35)
      83 ns: the kernel refuses it, line 17: this deadline wait can be reached 1 cycle late (slack -1..35)
          5 104 ns    designed 5 sweep true  OUT OF SPEC: T1L 104 ns (sheet >= 200 ns + a cycle), T 812 ns (sheet >= 1.2 us + a cycle)
          6 125 ns    designed 6 sweep true  OUT OF SPEC: T1L 125 ns (sheet >= 200 ns + a cycle), T 833 ns (sheet >= 1.2 us + a cycle)
          7 146 ns    designed 7 sweep true  OUT OF SPEC: T1L 146 ns (sheet >= 200 ns + a cycle), T 854 ns (sheet >= 1.2 us + a cycle)
          8 167 ns    designed 8 sweep true  OUT OF SPEC: T1L 167 ns (sheet >= 200 ns + a cycle), T 875 ns (sheet >= 1.2 us + a cycle)
          9 188 ns    designed 9 sweep true  OUT OF SPEC: T1L 188 ns (sheet >= 200 ns + a cycle), T 896 ns (sheet >= 1.2 us + a cycle)
         10 208 ns    designed 10 sweep true  OUT OF SPEC: T1L 208 ns (sheet >= 200 ns + a cycle), T 917 ns (sheet >= 1.2 us + a cycle)
         11 229 ns    designed 11 sweep true  OUT OF SPEC: T 938 ns (sheet >= 1.2 us + a cycle)
         12 250 ns    designed 12 sweep true  OUT OF SPEC: T 958 ns (sheet >= 1.2 us + a cycle)
         13 271 ns    designed 13 sweep true  OUT OF SPEC: T 979 ns (sheet >= 1.2 us + a cycle)
         14 292 ns    designed 14 sweep true  OUT OF SPEC: T 1 us (sheet >= 1.2 us + a cycle)
         15 312 ns    designed 15 sweep true  OUT OF SPEC: T 1.021 us (sheet >= 1.2 us + a cycle)
         16 333 ns    designed 16 sweep true  OUT OF SPEC: T 1.042 us (sheet >= 1.2 us + a cycle)
         17 354 ns    designed 17 sweep true  OUT OF SPEC: T 1.062 us (sheet >= 1.2 us + a cycle)
         18 375 ns    designed 18 sweep true  OUT OF SPEC: T 1.083 us (sheet >= 1.2 us + a cycle)
         19 396 ns    designed 19 sweep true  OUT OF SPEC: T 1.104 us (sheet >= 1.2 us + a cycle)
         20 417 ns    designed 20 sweep true  OUT OF SPEC: T 1.125 us (sheet >= 1.2 us + a cycle)
         21 438 ns    designed 21 sweep true  OUT OF SPEC: T 1.146 us (sheet >= 1.2 us + a cycle)
         22 458 ns    designed 22 sweep true  OUT OF SPEC: T 1.167 us (sheet >= 1.2 us + a cycle)
         23 479 ns    designed 23 sweep true  OUT OF SPEC: T 1.188 us (sheet >= 1.2 us + a cycle)
         24 500 ns    designed 24 sweep true  OUT OF SPEC: T 1.208 us (sheet >= 1.2 us + a cycle)
         25 521 ns    designed 25 sweep true  in spec
         26 542 ns    designed 26 sweep true  in spec
         27 562 ns    designed 27 sweep true  in spec
         28 583 ns    designed 28 sweep true  in spec
         29 604 ns    designed 29 sweep true  in spec
         30 625 ns    designed 30 sweep true  in spec
         31 646 ns    designed 31 sweep true  in spec
         32 667 ns    designed 32 sweep true  in spec
         33 688 ns    designed 33 sweep true  in spec
         34 708 ns    designed 34 sweep true  in spec
         35 729 ns    designed 35 sweep true  in spec
         36 750 ns    designed 36 sweep true  in spec
         37 771 ns    designed 37 sweep true  in spec
         38 792 ns    designed 38 sweep true  in spec
         39 812 ns    designed 39 sweep true  in spec
         40 833 ns    designed 40 sweep true  in spec
         41 854 ns    designed 41 sweep true  in spec
         42 875 ns    designed 42 sweep true  in spec
         43 896 ns    designed 43 sweep true  in spec
         44 917 ns    designed 44 sweep true  in spec
         45 938 ns    designed 45 sweep true  in spec
         46 958 ns    designed 46 sweep true  in spec
         47 979 ns    designed 47 sweep true  in spec
         48 1 us      designed 48 sweep true  in spec
         72 1.5 us    designed 72 sweep true  in spec
         96 2 us      designed 96 sweep true  in spec
        144 3 us      designed 144 sweep true  in spec
        192 4 us      designed 192 sweep true  in spec
        240 5 us      designed 240 sweep true  in spec
        288 6 us      designed 288 sweep true  in spec
        336 7 us      designed 336 sweep true  in spec
        384 8 us      designed 384 sweep true  in spec
        480 10 us     designed 480 sweep true  in spec
        576 12 us     designed 576 sweep true  in spec
        720 15 us     designed 720 sweep true  in spec
        960 20 us     designed 960 sweep true  OUT OF SPEC: T1L 20 us (sheet <= 20 us + a cycle)
       1200 25 us     designed 1200 sweep true  OUT OF SPEC: T1L 25 us (sheet <= 20 us + a cycle)
       1440 30 us     designed 1440 sweep true  OUT OF SPEC: T1L 30 us (sheet <= 20 us + a cycle)
       1920 40 us     designed 1920 sweep true  OUT OF SPEC: T1L 40 us (sheet <= 20 us + a cycle)
       2400 50 us     designed 2400 sweep true  OUT OF SPEC: T1L 50 us (sheet <= 20 us + a cycle)
       2880 60 us     designed 2880 sweep true  OUT OF SPEC: T1L 60 us (sheet <= 20 us + a cycle)
       3360 70 us     designed 3360 sweep true  OUT OF SPEC: T1L 70 us (sheet <= 20 us + a cycle)
       3840 80 us     designed 3840 sweep true  OUT OF SPEC: T1L 80 us (sheet <= 20 us + a cycle)
       4320 90 us     designed 4320 sweep true  OUT OF SPEC: T1L 90 us (sheet <= 20 us + a cycle)
       4800 100 us    designed 4800 sweep true  OUT OF SPEC: T1L 100 us (sheet <= 20 us + a cycle)
       5280 110 us    designed 5280 sweep true  OUT OF SPEC: T1L 110 us (sheet <= 20 us + a cycle)
       5760 120 us    designed 5760 sweep true  OUT OF SPEC: T1L 120 us (sheet <= 20 us + a cycle)
    SK6812 reset
         48 1 us      designed 48 sweep true  OUT OF SPEC: reset 1 us (sheet >= 200 us + a cycle)
         96 2 us      designed 96 sweep true  OUT OF SPEC: reset 2 us (sheet >= 200 us + a cycle)
        144 3 us      designed 144 sweep true  OUT OF SPEC: reset 3 us (sheet >= 200 us + a cycle)
        192 4 us      designed 192 sweep true  OUT OF SPEC: reset 4 us (sheet >= 200 us + a cycle)
        240 5 us      designed 240 sweep true  OUT OF SPEC: reset 5 us (sheet >= 200 us + a cycle)
        288 6 us      designed 288 sweep true  OUT OF SPEC: reset 6 us (sheet >= 200 us + a cycle)
        336 7 us      designed 336 sweep true  OUT OF SPEC: reset 7 us (sheet >= 200 us + a cycle)
        384 8 us      designed 384 sweep true  OUT OF SPEC: reset 8 us (sheet >= 200 us + a cycle)
        432 9 us      designed 432 sweep true  OUT OF SPEC: reset 9 us (sheet >= 200 us + a cycle)
        480 10 us     designed 480 sweep true  OUT OF SPEC: reset 10 us (sheet >= 200 us + a cycle)
        576 12 us     designed 576 sweep true  OUT OF SPEC: reset 12 us (sheet >= 200 us + a cycle)
        672 14 us     designed 672 sweep true  OUT OF SPEC: reset 14 us (sheet >= 200 us + a cycle)
        768 16 us     designed 768 sweep true  OUT OF SPEC: reset 16 us (sheet >= 200 us + a cycle)
        864 18 us     designed 864 sweep true  OUT OF SPEC: reset 18 us (sheet >= 200 us + a cycle)
        960 20 us     designed 960 sweep true  OUT OF SPEC: reset 20 us (sheet >= 200 us + a cycle)
       1200 25 us     designed 1200 sweep true  OUT OF SPEC: reset 25 us (sheet >= 200 us + a cycle)
       1440 30 us     designed 1440 sweep true  OUT OF SPEC: reset 30 us (sheet >= 200 us + a cycle)
       1680 35 us     designed 1680 sweep true  OUT OF SPEC: reset 35 us (sheet >= 200 us + a cycle)
       1920 40 us     designed 1920 sweep true  OUT OF SPEC: reset 40 us (sheet >= 200 us + a cycle)
       2400 50 us     designed 2400 sweep true  OUT OF SPEC: reset 50 us (sheet >= 200 us + a cycle)
       2880 60 us     designed 2880 sweep true  OUT OF SPEC: reset 60 us (sheet >= 200 us + a cycle)
       3360 70 us     designed 3360 sweep true  OUT OF SPEC: reset 70 us (sheet >= 200 us + a cycle)
       3840 80 us     designed 3840 sweep true  OUT OF SPEC: reset 80 us (sheet >= 200 us + a cycle)
       4800 100 us    designed 4800 sweep true  OUT OF SPEC: reset 100 us (sheet >= 200 us + a cycle)
       4896 102 us    designed 4896 sweep true  OUT OF SPEC: reset 102 us (sheet >= 200 us + a cycle)
       4992 104 us    designed 4992 sweep true  OUT OF SPEC: reset 104 us (sheet >= 200 us + a cycle)
       5088 106 us    designed 5088 sweep true  OUT OF SPEC: reset 106 us (sheet >= 200 us + a cycle)
       5184 108 us    designed 5184 sweep true  OUT OF SPEC: reset 108 us (sheet >= 200 us + a cycle)
       5280 110 us    designed 5280 sweep true  OUT OF SPEC: reset 110 us (sheet >= 200 us + a cycle)
       5376 112 us    designed 5376 sweep true  OUT OF SPEC: reset 112 us (sheet >= 200 us + a cycle)
       5472 114 us    designed 5472 sweep true  OUT OF SPEC: reset 114 us (sheet >= 200 us + a cycle)
       5568 116 us    designed 5568 sweep true  OUT OF SPEC: reset 116 us (sheet >= 200 us + a cycle)
       5664 118 us    designed 5664 sweep true  OUT OF SPEC: reset 118 us (sheet >= 200 us + a cycle)
       5760 120 us    designed 5760 sweep true  OUT OF SPEC: reset 120 us (sheet >= 200 us + a cycle)
       7200 150 us    designed 7200 sweep true  OUT OF SPEC: reset 150 us (sheet >= 200 us + a cycle)
       9600 200 us    designed 9600 sweep true  OUT OF SPEC: reset 200 us (sheet >= 200 us + a cycle)
      12000 250 us    designed 12000 sweep true  in spec
      14400 300 us    designed 14400 sweep true  in spec
    24LC256 1/fSCL
        192 4 us      designed 192 sweep true  in spec
        160 3.333 us  designed 160 sweep true  OUT OF SPEC: TSU:STA 833 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:STO 833 ns (sheet >= 600 ns + 300 ns TR, param 4)
        128 2.667 us  designed 128 sweep true  OUT OF SPEC: TSU:STA 667 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:STO 667 ns (sheet >= 600 ns + 300 ns TR, param 4)
        112 2.333 us  designed 112 sweep true  OUT OF SPEC: 1/fSCL 2.333 us (sheet >= 2.5 us + a cycle), TLOW 1.167 us (sheet >= 1.3 us + a cycle), THD:STA 583 ns (sheet >= 600 ns + a cycle), TSU:STA 583 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:STO 583 ns (sheet >= 600 ns + 300 ns TR, param 4)
         96 2 us      designed 96 sweep true  OUT OF SPEC: 1/fSCL 2 us (sheet >= 2.5 us + a cycle), TLOW 1 us (sheet >= 1.3 us + a cycle), THD:STA 500 ns (sheet >= 600 ns + a cycle), TSU:STA 500 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:STO 500 ns (sheet >= 600 ns + 300 ns TR, param 4)
         80 1.667 us  designed 80 sweep true  OUT OF SPEC: 1/fSCL 1.667 us (sheet >= 2.5 us + a cycle), THIGH 833 ns (sheet >= 600 ns + 300 ns TR, param 4), TLOW 833 ns (sheet >= 1.3 us + a cycle), THD:STA 417 ns (sheet >= 600 ns + a cycle), TSU:STA 417 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:DAT 396 ns (sheet >= 100 ns + 300 ns TR, param 4), TSU:STO 417 ns (sheet >= 600 ns + 300 ns TR, param 4), TBUF 1.354 us (sheet >= 1.3 us + 300 ns TR, param 4)
         72 1.5 us    designed 72 sweep true  OUT OF SPEC: 1/fSCL 1.5 us (sheet >= 2.5 us + a cycle), THIGH 750 ns (sheet >= 600 ns + 300 ns TR, param 4), TLOW 750 ns (sheet >= 1.3 us + a cycle), THD:STA 375 ns (sheet >= 600 ns + a cycle), TSU:STA 375 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:DAT 354 ns (sheet >= 100 ns + 300 ns TR, param 4), TSU:STO 375 ns (sheet >= 600 ns + 300 ns TR, param 4), TBUF 1.229 us (sheet >= 1.3 us + 300 ns TR, param 4)
         64 1.333 us  designed 64 sweep true  OUT OF SPEC: 1/fSCL 1.333 us (sheet >= 2.5 us + a cycle), THIGH 667 ns (sheet >= 600 ns + 300 ns TR, param 4), TLOW 667 ns (sheet >= 1.3 us + a cycle), THD:STA 333 ns (sheet >= 600 ns + a cycle), TSU:STA 333 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:DAT 312 ns (sheet >= 100 ns + 300 ns TR, param 4), TSU:STO 333 ns (sheet >= 600 ns + 300 ns TR, param 4), TBUF 1.104 us (sheet >= 1.3 us + 300 ns TR, param 4)
         56 1.167 us  designed 56 sweep true  OUT OF SPEC: 1/fSCL 1.167 us (sheet >= 2.5 us + a cycle), THIGH 583 ns (sheet >= 600 ns + 300 ns TR, param 4), TLOW 583 ns (sheet >= 1.3 us + a cycle), THD:STA 292 ns (sheet >= 600 ns + a cycle), TSU:STA 292 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:DAT 271 ns (sheet >= 100 ns + 300 ns TR, param 4), TSU:STO 292 ns (sheet >= 600 ns + 300 ns TR, param 4), TBUF 979 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         48 1 us      designed 48 sweep true  OUT OF SPEC: 1/fSCL 1 us (sheet >= 2.5 us + a cycle), THIGH 500 ns (sheet >= 600 ns + 300 ns TR, param 4), TLOW 500 ns (sheet >= 1.3 us + a cycle), THD:STA 250 ns (sheet >= 600 ns + a cycle), TSU:STA 250 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:DAT 229 ns (sheet >= 100 ns + 300 ns TR, param 4), TSU:STO 250 ns (sheet >= 600 ns + 300 ns TR, param 4), TBUF 854 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         44 917 ns    designed 44 sweep true  OUT OF SPEC: 1/fSCL 917 ns (sheet >= 2.5 us + a cycle), THIGH 458 ns (sheet >= 600 ns + 300 ns TR, param 4), TLOW 458 ns (sheet >= 1.3 us + a cycle), THD:STA 229 ns (sheet >= 600 ns + a cycle), TSU:STA 229 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:DAT 208 ns (sheet >= 100 ns + 300 ns TR, param 4), TSU:STO 229 ns (sheet >= 600 ns + 300 ns TR, param 4), TBUF 792 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         40 833 ns    designed 40 sweep true  OUT OF SPEC: 1/fSCL 833 ns (sheet >= 2.5 us + a cycle), THIGH 417 ns (sheet >= 600 ns + 300 ns TR, param 4), TLOW 417 ns (sheet >= 1.3 us + a cycle), THD:STA 208 ns (sheet >= 600 ns + a cycle), TSU:STA 208 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:DAT 188 ns (sheet >= 100 ns + 300 ns TR, param 4), TSU:STO 208 ns (sheet >= 600 ns + 300 ns TR, param 4), TBUF 729 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         36 750 ns    designed 36 sweep true  OUT OF SPEC: 1/fSCL 750 ns (sheet >= 2.5 us + a cycle), THIGH 375 ns (sheet >= 600 ns + 300 ns TR, param 4), TLOW 375 ns (sheet >= 1.3 us + a cycle), THD:STA 188 ns (sheet >= 600 ns + a cycle), TSU:STA 188 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:DAT 167 ns (sheet >= 100 ns + 300 ns TR, param 4), TSU:STO 188 ns (sheet >= 600 ns + 300 ns TR, param 4), TBUF 667 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         32 667 ns    designed 32 sweep true  OUT OF SPEC: 1/fSCL 667 ns (sheet >= 2.5 us + a cycle), THIGH 333 ns (sheet >= 600 ns + 300 ns TR, param 4), TLOW 333 ns (sheet >= 1.3 us + a cycle), THD:STA 167 ns (sheet >= 600 ns + a cycle), TSU:STA 167 ns (sheet >= 600 ns + 300 ns TR, param 4), TSU:DAT 146 ns (sheet >= 100 ns + 300 ns TR, param 4), TSU:STO 167 ns (sheet >= 600 ns + 300 ns TR, param 4), TBUF 604 ns (sheet >= 1.3 us + 300 ns TR, param 4)
      583 ns: the kernel refuses it, line 90: this deadline wait can be reached 1 cycle late (slack -1..1)
      500 ns: the kernel refuses it, line 67: this deadline wait can be reached 1 cycle late (slack -1..4)
      417 ns: the kernel refuses it, line 45: this deadline wait can be reached 2 cycles late (slack -2..3)
      333 ns: the kernel refuses it, line 45: this deadline wait can be reached 4 cycles late (slack -4..1)
      250 ns: the kernel refuses it, line 33: this deadline wait can be reached 1 cycle late (slack -1)
    24LC256 THD:STA
      21 ns: the kernel refuses it, line 28: this deadline wait can be reached 2 cycles late (slack -2)
          3 62 ns     designed 3 sweep true  OUT OF SPEC: THD:STA 62 ns (sheet >= 600 ns + a cycle)
          5 104 ns    designed 5 sweep true  OUT OF SPEC: THD:STA 104 ns (sheet >= 600 ns + a cycle)
          7 146 ns    designed 7 sweep true  OUT OF SPEC: THD:STA 146 ns (sheet >= 600 ns + a cycle)
          9 188 ns    designed 9 sweep true  OUT OF SPEC: THD:STA 188 ns (sheet >= 600 ns + a cycle)
         11 229 ns    designed 11 sweep true  OUT OF SPEC: THD:STA 229 ns (sheet >= 600 ns + a cycle)
         13 271 ns    designed 13 sweep true  OUT OF SPEC: THD:STA 271 ns (sheet >= 600 ns + a cycle)
         15 312 ns    designed 15 sweep true  OUT OF SPEC: THD:STA 312 ns (sheet >= 600 ns + a cycle)
         17 354 ns    designed 17 sweep true  OUT OF SPEC: THD:STA 354 ns (sheet >= 600 ns + a cycle)
         19 396 ns    designed 19 sweep true  OUT OF SPEC: THD:STA 396 ns (sheet >= 600 ns + a cycle)
         21 438 ns    designed 21 sweep true  OUT OF SPEC: THD:STA 438 ns (sheet >= 600 ns + a cycle)
         23 479 ns    designed 23 sweep true  OUT OF SPEC: THD:STA 479 ns (sheet >= 600 ns + a cycle)
         25 521 ns    designed 25 sweep true  OUT OF SPEC: THD:STA 521 ns (sheet >= 600 ns + a cycle)
         27 562 ns    designed 27 sweep true  OUT OF SPEC: THD:STA 562 ns (sheet >= 600 ns + a cycle)
         29 604 ns    designed 29 sweep true  OUT OF SPEC: THD:STA 604 ns (sheet >= 600 ns + a cycle)
         31 646 ns    designed 31 sweep true  in spec
         33 688 ns    designed 33 sweep true  in spec
         35 729 ns    designed 35 sweep true  in spec
         37 771 ns    designed 37 sweep true  in spec
         39 812 ns    designed 39 sweep true  in spec
         41 854 ns    designed 41 sweep true  in spec
         43 896 ns    designed 43 sweep true  in spec
         45 938 ns    designed 45 sweep true  in spec
         47 979 ns    designed 47 sweep true  in spec
         49 1.021 us  designed 49 sweep true  in spec
         51 1.062 us  designed 51 sweep true  in spec
         53 1.104 us  designed 53 sweep true  in spec
         55 1.146 us  designed 55 sweep true  in spec
         57 1.188 us  designed 57 sweep true  in spec
         59 1.229 us  designed 59 sweep true  in spec
    24LC256 TSU:DAT
      21 ns: the kernel refuses it, line 49: this deadline wait can be reached 2 cycles late (slack -2)
      42 ns: the kernel refuses it, line 49: this deadline wait can be reached 1 cycle late (slack -1)
          3 62 ns     designed 3 sweep true  OUT OF SPEC: TSU:DAT 62 ns (sheet >= 100 ns + 300 ns TR, param 4)
          4 83 ns     designed 4 sweep true  OUT OF SPEC: TSU:DAT 83 ns (sheet >= 100 ns + 300 ns TR, param 4)
          5 104 ns    designed 5 sweep true  OUT OF SPEC: TSU:DAT 104 ns (sheet >= 100 ns + 300 ns TR, param 4)
          6 125 ns    designed 6 sweep true  OUT OF SPEC: TSU:DAT 125 ns (sheet >= 100 ns + 300 ns TR, param 4)
          7 146 ns    designed 7 sweep true  OUT OF SPEC: TSU:DAT 146 ns (sheet >= 100 ns + 300 ns TR, param 4)
          8 167 ns    designed 8 sweep true  OUT OF SPEC: TSU:DAT 167 ns (sheet >= 100 ns + 300 ns TR, param 4)
          9 188 ns    designed 9 sweep true  OUT OF SPEC: TSU:DAT 188 ns (sheet >= 100 ns + 300 ns TR, param 4)
         10 208 ns    designed 10 sweep true  OUT OF SPEC: TSU:DAT 208 ns (sheet >= 100 ns + 300 ns TR, param 4)
         11 229 ns    designed 11 sweep true  OUT OF SPEC: TSU:DAT 229 ns (sheet >= 100 ns + 300 ns TR, param 4)
         12 250 ns    designed 12 sweep true  OUT OF SPEC: TSU:DAT 250 ns (sheet >= 100 ns + 300 ns TR, param 4)
         13 271 ns    designed 13 sweep true  OUT OF SPEC: TSU:DAT 271 ns (sheet >= 100 ns + 300 ns TR, param 4)
         14 292 ns    designed 14 sweep true  OUT OF SPEC: TSU:DAT 292 ns (sheet >= 100 ns + 300 ns TR, param 4)
         15 312 ns    designed 15 sweep true  OUT OF SPEC: TSU:DAT 312 ns (sheet >= 100 ns + 300 ns TR, param 4)
         16 333 ns    designed 16 sweep true  OUT OF SPEC: TSU:DAT 333 ns (sheet >= 100 ns + 300 ns TR, param 4)
         17 354 ns    designed 17 sweep true  OUT OF SPEC: TSU:DAT 354 ns (sheet >= 100 ns + 300 ns TR, param 4)
         18 375 ns    designed 18 sweep true  OUT OF SPEC: TSU:DAT 375 ns (sheet >= 100 ns + 300 ns TR, param 4)
         19 396 ns    designed 19 sweep true  OUT OF SPEC: TSU:DAT 396 ns (sheet >= 100 ns + 300 ns TR, param 4)
         20 417 ns    designed 20 sweep true  in spec
         21 438 ns    designed 21 sweep true  in spec
         22 458 ns    designed 22 sweep true  in spec
         23 479 ns    designed 23 sweep true  in spec
         24 500 ns    designed 24 sweep true  in spec
         25 521 ns    designed 25 sweep true  in spec
         26 542 ns    designed 26 sweep true  in spec
         27 562 ns    designed 27 sweep true  in spec
         28 583 ns    designed 28 sweep true  in spec
         29 604 ns    designed 29 sweep true  in spec
         30 625 ns    designed 30 sweep true  in spec
         31 646 ns    designed 31 sweep true  in spec
         32 667 ns    designed 32 sweep true  in spec
         33 688 ns    designed 33 sweep true  in spec
         34 708 ns    designed 34 sweep true  in spec
         35 729 ns    designed 35 sweep true  in spec
         36 750 ns    designed 36 sweep true  in spec
         37 771 ns    designed 37 sweep true  in spec
         38 792 ns    designed 38 sweep true  in spec
         39 812 ns    designed 39 sweep true  in spec
         40 833 ns    designed 40 sweep true  in spec
         44 917 ns    designed 44 sweep true  in spec
         48 1 us      designed 48 sweep true  in spec
         56 1.167 us  designed 56 sweep true  in spec
         64 1.333 us  designed 64 sweep true  in spec
         70 1.458 us  designed 70 sweep true  in spec
    24LC256 TBUF
      125 ns: the kernel refuses it, line 23: this deadline wait can be reached 4 cycles late (slack -4)
      167 ns: the kernel refuses it, line 24: this deadline wait can be reached 3 cycles late (slack -3)
      208 ns: the kernel refuses it, line 24: this deadline wait can be reached 1 cycle late (slack -1)
      250 ns: the kernel refuses it, line 44: this deadline wait can be reached 5 cycles late (slack -5..89)
      292 ns: the kernel refuses it, line 45: this deadline wait can be reached 4 cycles late (slack -4..89)
      333 ns: the kernel refuses it, line 45: this deadline wait can be reached 2 cycles late (slack -2..89)
      375 ns: the kernel refuses it, line 67: this deadline wait can be reached 1 cycle late (slack -1..88)
         20 417 ns    designed 20 sweep true  OUT OF SPEC: TBUF 417 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         22 458 ns    designed 22 sweep true  OUT OF SPEC: TBUF 458 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         24 500 ns    designed 24 sweep true  OUT OF SPEC: TBUF 500 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         26 542 ns    designed 26 sweep true  OUT OF SPEC: TBUF 542 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         28 583 ns    designed 28 sweep true  OUT OF SPEC: TBUF 583 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         30 625 ns    designed 30 sweep true  OUT OF SPEC: TBUF 625 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         32 667 ns    designed 32 sweep true  OUT OF SPEC: TBUF 667 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         34 708 ns    designed 34 sweep true  OUT OF SPEC: TBUF 708 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         36 750 ns    designed 36 sweep true  OUT OF SPEC: TBUF 750 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         38 792 ns    designed 38 sweep true  OUT OF SPEC: TBUF 792 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         40 833 ns    designed 40 sweep true  OUT OF SPEC: TBUF 833 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         42 875 ns    designed 42 sweep true  OUT OF SPEC: TBUF 875 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         44 917 ns    designed 44 sweep true  OUT OF SPEC: TBUF 917 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         46 958 ns    designed 46 sweep true  OUT OF SPEC: TBUF 958 ns (sheet >= 1.3 us + 300 ns TR, param 4)
         48 1 us      designed 48 sweep true  OUT OF SPEC: TBUF 1 us (sheet >= 1.3 us + 300 ns TR, param 4)
         50 1.042 us  designed 50 sweep true  OUT OF SPEC: TBUF 1.042 us (sheet >= 1.3 us + 300 ns TR, param 4)
         52 1.083 us  designed 52 sweep true  OUT OF SPEC: TBUF 1.083 us (sheet >= 1.3 us + 300 ns TR, param 4)
         54 1.125 us  designed 54 sweep true  OUT OF SPEC: TBUF 1.125 us (sheet >= 1.3 us + 300 ns TR, param 4)
         56 1.167 us  designed 56 sweep true  OUT OF SPEC: TBUF 1.167 us (sheet >= 1.3 us + 300 ns TR, param 4)
         58 1.208 us  designed 58 sweep true  OUT OF SPEC: TBUF 1.208 us (sheet >= 1.3 us + 300 ns TR, param 4)
         60 1.25 us   designed 60 sweep true  OUT OF SPEC: TBUF 1.25 us (sheet >= 1.3 us + 300 ns TR, param 4)
         62 1.292 us  designed 62 sweep true  OUT OF SPEC: TBUF 1.292 us (sheet >= 1.3 us + 300 ns TR, param 4)
         64 1.333 us  designed 64 sweep true  OUT OF SPEC: TBUF 1.333 us (sheet >= 1.3 us + 300 ns TR, param 4)
         66 1.375 us  designed 66 sweep true  OUT OF SPEC: TBUF 1.375 us (sheet >= 1.3 us + 300 ns TR, param 4)
         68 1.417 us  designed 68 sweep true  OUT OF SPEC: TBUF 1.417 us (sheet >= 1.3 us + 300 ns TR, param 4)
         70 1.458 us  designed 70 sweep true  OUT OF SPEC: TBUF 1.458 us (sheet >= 1.3 us + 300 ns TR, param 4)
         72 1.5 us    designed 72 sweep true  OUT OF SPEC: TBUF 1.5 us (sheet >= 1.3 us + 300 ns TR, param 4)
         74 1.542 us  designed 74 sweep true  OUT OF SPEC: TBUF 1.542 us (sheet >= 1.3 us + 300 ns TR, param 4)
         76 1.583 us  designed 76 sweep true  OUT OF SPEC: TBUF 1.583 us (sheet >= 1.3 us + 300 ns TR, param 4)
         78 1.625 us  designed 78 sweep true  in spec
         80 1.667 us  designed 80 sweep true  in spec
         90 1.875 us  designed 90 sweep true  in spec
        100 2.083 us  designed 100 sweep true  in spec
        120 2.5 us    designed 120 sweep true  in spec
        149 3.104 us  designed 149 sweep true  in spec
    DS18B20 tRSTL
        240 5 us      designed 240 sweep true  OUT OF SPEC: tRSTL 5 us (sheet >= 480 us + a cycle)
        480 10 us     designed 480 sweep true  OUT OF SPEC: tRSTL 10 us (sheet >= 480 us + a cycle)
        720 15 us     designed 720 sweep true  OUT OF SPEC: tRSTL 15 us (sheet >= 480 us + a cycle)
        960 20 us     designed 960 sweep true  OUT OF SPEC: tRSTL 20 us (sheet >= 480 us + a cycle)
       1200 25 us     designed 1200 sweep true  OUT OF SPEC: tRSTL 25 us (sheet >= 480 us + a cycle)
       1440 30 us     designed 1440 sweep true  OUT OF SPEC: tRSTL 30 us (sheet >= 480 us + a cycle)
       1920 40 us     designed 1920 sweep true  OUT OF SPEC: tRSTL 40 us (sheet >= 480 us + a cycle)
       2400 50 us     designed 2400 sweep true  OUT OF SPEC: tRSTL 50 us (sheet >= 480 us + a cycle)
       2880 60 us     designed 2880 sweep true  OUT OF SPEC: tRSTL 60 us (sheet >= 480 us + a cycle)
       3360 70 us     designed 3360 sweep true  OUT OF SPEC: tRSTL 70 us (sheet >= 480 us + a cycle)
       3840 80 us     designed 3840 sweep true  OUT OF SPEC: tRSTL 80 us (sheet >= 480 us + a cycle)
       4320 90 us     designed 4320 sweep true  OUT OF SPEC: tRSTL 90 us (sheet >= 480 us + a cycle)
       4800 100 us    designed 4800 sweep true  OUT OF SPEC: tRSTL 100 us (sheet >= 480 us + a cycle)
       5760 120 us    designed 5760 sweep true  OUT OF SPEC: tRSTL 120 us (sheet >= 480 us + a cycle)
       6720 140 us    designed 6720 sweep true  OUT OF SPEC: tRSTL 140 us (sheet >= 480 us + a cycle)
       7680 160 us    designed 7680 sweep true  OUT OF SPEC: tRSTL 160 us (sheet >= 480 us + a cycle)
       9600 200 us    designed 9600 sweep true  OUT OF SPEC: tRSTL 200 us (sheet >= 480 us + a cycle)
       9840 205 us    designed 9840 sweep true  OUT OF SPEC: tRSTL 205 us (sheet >= 480 us + a cycle)
      10080 210 us    designed 10080 sweep true  OUT OF SPEC: tRSTL 210 us (sheet >= 480 us + a cycle)
      10320 215 us    designed 10320 sweep true  OUT OF SPEC: tRSTL 215 us (sheet >= 480 us + a cycle)
      10560 220 us    designed 10560 sweep true  OUT OF SPEC: tRSTL 220 us (sheet >= 480 us + a cycle)
      10800 225 us    designed 10800 sweep true  OUT OF SPEC: tRSTL 225 us (sheet >= 480 us + a cycle)
      11040 230 us    designed 11040 sweep true  OUT OF SPEC: tRSTL 230 us (sheet >= 480 us + a cycle)
      11280 235 us    designed 11280 sweep true  OUT OF SPEC: tRSTL 235 us (sheet >= 480 us + a cycle)
      11520 240 us    designed 11520 sweep true  OUT OF SPEC: tRSTL 240 us (sheet >= 480 us + a cycle)
      14400 300 us    designed 14400 sweep true  OUT OF SPEC: tRSTL 300 us (sheet >= 480 us + a cycle)
      19200 400 us    designed 19200 sweep true  OUT OF SPEC: tRSTL 400 us (sheet >= 480 us + a cycle)
      23040 480 us    designed 23040 sweep true  OUT OF SPEC: tRSTL 480 us (sheet >= 480 us + a cycle)
      24192 504 us    designed 24192 sweep true  in spec
    DS18B20 presence sample
         96 2 us      designed 96 sweep true  OUT OF SPEC: presence sample 2 us (sheet >= 60 us + a cycle)
        240 5 us      designed 240 sweep true  OUT OF SPEC: presence sample 5 us (sheet >= 60 us + a cycle)
        480 10 us     designed 480 sweep true  OUT OF SPEC: presence sample 10 us (sheet >= 60 us + a cycle)
        720 15 us     designed 720 sweep true  OUT OF SPEC: presence sample 15 us (sheet >= 60 us + a cycle)
        960 20 us     designed 960 sweep true  OUT OF SPEC: presence sample 20 us (sheet >= 60 us + a cycle)
       1200 25 us     designed 1200 sweep true  OUT OF SPEC: presence sample 25 us (sheet >= 60 us + a cycle)
       1440 30 us     designed 1440 sweep true  OUT OF SPEC: presence sample 30 us (sheet >= 60 us + a cycle)
       1488 31 us     designed 1488 sweep true  OUT OF SPEC: presence sample 31 us (sheet >= 60 us + a cycle)
       1536 32 us     designed 1536 sweep true  OUT OF SPEC: presence sample 32 us (sheet >= 60 us + a cycle)
       1584 33 us     designed 1584 sweep true  OUT OF SPEC: presence sample 33 us (sheet >= 60 us + a cycle)
       1632 34 us     designed 1632 sweep true  OUT OF SPEC: presence sample 34 us (sheet >= 60 us + a cycle)
       1680 35 us     designed 1680 sweep true  OUT OF SPEC: presence sample 35 us (sheet >= 60 us + a cycle)
       1920 40 us     designed 1920 sweep true  OUT OF SPEC: presence sample 40 us (sheet >= 60 us + a cycle)
       2160 45 us     designed 2160 sweep true  OUT OF SPEC: presence sample 45 us (sheet >= 60 us + a cycle)
       2400 50 us     designed 2400 sweep true  OUT OF SPEC: presence sample 50 us (sheet >= 60 us + a cycle)
       2640 55 us     designed 2640 sweep true  OUT OF SPEC: presence sample 55 us (sheet >= 60 us + a cycle)
       2880 60 us     designed 2880 sweep true  OUT OF SPEC: presence sample 60 us (sheet >= 60 us + a cycle)
       3120 65 us     designed 3120 sweep true  in spec
       3360 70 us     designed 3360 sweep true  in spec
       3456 72 us     designed 3456 sweep true  in spec
       3600 75 us     designed 3600 sweep true  OUT OF SPEC: presence sample 75 us (sheet <= 75 us + a cycle)
       3840 80 us     designed 3840 sweep true  OUT OF SPEC: presence sample 80 us (sheet <= 75 us + a cycle)
       4320 90 us     designed 4320 sweep true  OUT OF SPEC: presence sample 90 us (sheet <= 75 us + a cycle)
       4800 100 us    designed 4800 sweep true  OUT OF SPEC: presence sample 100 us (sheet <= 75 us + a cycle)
       5760 120 us    designed 5760 sweep true  OUT OF SPEC: presence sample 120 us (sheet <= 75 us + a cycle)
       6720 140 us    designed 6720 sweep true  OUT OF SPEC: presence sample 140 us (sheet <= 75 us + a cycle)
       6960 145 us    designed 6960 sweep true  OUT OF SPEC: presence sample 145 us (sheet <= 75 us + a cycle)
       7200 150 us    designed 7200 sweep true  OUT OF SPEC: presence sample 150 us (sheet <= 75 us + a cycle)
       7440 155 us    designed 7440 sweep true  OUT OF SPEC: presence sample 155 us (sheet <= 75 us + a cycle)
       7680 160 us    designed 7680 sweep true  OUT OF SPEC: presence sample 160 us (sheet <= 75 us + a cycle)
       8640 180 us    designed 8640 sweep true  OUT OF SPEC: presence sample 180 us (sheet <= 75 us + a cycle)
       9600 200 us    designed 9600 sweep true  OUT OF SPEC: presence sample 200 us (sheet <= 75 us + a cycle)
      10560 220 us    designed 10560 sweep true  OUT OF SPEC: presence sample 220 us (sheet <= 75 us + a cycle)
      11520 240 us    designed 11520 sweep true  OUT OF SPEC: presence sample 240 us (sheet <= 75 us + a cycle)
      12480 260 us    designed 12480 sweep true  OUT OF SPEC: presence sample 260 us (sheet <= 75 us + a cycle)
      13440 280 us    designed 13440 sweep true  OUT OF SPEC: presence sample 280 us (sheet <= 75 us + a cycle)
      14400 300 us    designed 14400 sweep true  OUT OF SPEC: presence sample 300 us (sheet <= 75 us + a cycle)
    DS18B20 tLOW0
         96 2 us      designed 96 sweep true  OUT OF SPEC: tLOW1 1 us (sheet >= 1 us + a cycle), tLOW0 2 us (sheet >= 60 us + a cycle)
        192 4 us      designed 192 sweep true  OUT OF SPEC: tLOW0 4 us (sheet >= 60 us + a cycle)
        288 6 us      designed 288 sweep true  OUT OF SPEC: tLOW0 6 us (sheet >= 60 us + a cycle)
        384 8 us      designed 384 sweep true  OUT OF SPEC: tLOW0 8 us (sheet >= 60 us + a cycle)
        480 10 us     designed 480 sweep true  OUT OF SPEC: tLOW0 10 us (sheet >= 60 us + a cycle)
        576 12 us     designed 576 sweep true  OUT OF SPEC: tLOW0 12 us (sheet >= 60 us + a cycle)
        672 14 us     designed 672 sweep true  OUT OF SPEC: tLOW0 14 us (sheet >= 60 us + a cycle)
        768 16 us     designed 768 sweep true  OUT OF SPEC: tLOW0 16 us (sheet >= 60 us + a cycle)
        864 18 us     designed 864 sweep true  OUT OF SPEC: tLOW0 18 us (sheet >= 60 us + a cycle)
        960 20 us     designed 960 sweep true  OUT OF SPEC: tLOW0 20 us (sheet >= 60 us + a cycle)
       1056 22 us     designed 1056 sweep true  OUT OF SPEC: tLOW0 22 us (sheet >= 60 us + a cycle)
       1152 24 us     designed 1152 sweep true  OUT OF SPEC: tLOW0 24 us (sheet >= 60 us + a cycle)
       1248 26 us     designed 1248 sweep true  OUT OF SPEC: tLOW0 26 us (sheet >= 60 us + a cycle)
       1344 28 us     designed 1344 sweep true  OUT OF SPEC: tLOW0 28 us (sheet >= 60 us + a cycle)
       1392 29 us     designed 1392 sweep true  OUT OF SPEC: tLOW0 29 us (sheet >= 60 us + a cycle)
       1440 30 us     designed 1440 sweep true  OUT OF SPEC: tLOW0 30 us (sheet >= 60 us + a cycle)
       1536 32 us     designed 1536 sweep true  OUT OF SPEC: tLOW0 32 us (sheet >= 60 us + a cycle)
       1680 35 us     designed 1680 sweep true  OUT OF SPEC: tLOW0 35 us (sheet >= 60 us + a cycle)
       1920 40 us     designed 1920 sweep true  OUT OF SPEC: tLOW0 40 us (sheet >= 60 us + a cycle)
       2160 45 us     designed 2160 sweep true  OUT OF SPEC: tLOW0 45 us (sheet >= 60 us + a cycle)
       2400 50 us     designed 2400 sweep true  OUT OF SPEC: tLOW0 50 us (sheet >= 60 us + a cycle)
       2640 55 us     designed 2640 sweep true  OUT OF SPEC: tLOW0 55 us (sheet >= 60 us + a cycle)
       2880 60 us     designed 2880 sweep true  OUT OF SPEC: tLOW0 60 us (sheet >= 60 us + a cycle)
       3168 66 us     designed 3168 sweep true  in spec
       3840 80 us     designed 3840 sweep true  in spec
       4800 100 us    designed 4800 sweep true  in spec
       5472 114 us    designed 5472 sweep true  in spec
    DS18B20 tLOW1
         48 1 us      designed 48 sweep true  OUT OF SPEC: tLOW1 1 us (sheet >= 1 us + a cycle)
         96 2 us      designed 96 sweep true  in spec
        144 3 us      designed 144 sweep true  in spec
        192 4 us      designed 192 sweep true  in spec
        240 5 us      designed 240 sweep true  in spec
        288 6 us      designed 288 sweep true  in spec
        384 8 us      designed 384 sweep true  in spec
        480 10 us     designed 480 sweep true  in spec
        576 12 us     designed 576 sweep true  in spec
        672 14 us     designed 672 sweep true  in spec
        720 15 us     designed 720 sweep true  OUT OF SPEC: tLOW1 15 us (sheet <= 15 us + a cycle)
        768 16 us     designed 768 sweep true  OUT OF SPEC: tLOW1 16 us (sheet <= 15 us + a cycle)
        864 18 us     designed 864 sweep true  OUT OF SPEC: tLOW1 18 us (sheet <= 15 us + a cycle)
        960 20 us     designed 960 sweep true  OUT OF SPEC: tLOW1 20 us (sheet <= 15 us + a cycle)
       1056 22 us     designed 1056 sweep true  OUT OF SPEC: tLOW1 22 us (sheet <= 15 us + a cycle)
       1152 24 us     designed 1152 sweep true  OUT OF SPEC: tLOW1 24 us (sheet <= 15 us + a cycle)
       1248 26 us     designed 1248 sweep true  OUT OF SPEC: tLOW1 26 us (sheet <= 15 us + a cycle)
       1344 28 us     designed 1344 sweep true  OUT OF SPEC: tLOW1 28 us (sheet <= 15 us + a cycle)
       1392 29 us     designed 1392 sweep true  OUT OF SPEC: tLOW1 29 us (sheet <= 15 us + a cycle)
       1440 30 us     designed 1440 sweep true  OUT OF SPEC: tLOW1 30 us (sheet <= 15 us + a cycle)
       1536 32 us     designed 1536 sweep true  OUT OF SPEC: tLOW1 32 us (sheet <= 15 us + a cycle)
       1680 35 us     designed 1680 sweep true  OUT OF SPEC: tLOW1 35 us (sheet <= 15 us + a cycle)
       1920 40 us     designed 1920 sweep true  OUT OF SPEC: tLOW1 40 us (sheet <= 15 us + a cycle)
       2160 45 us     designed 2160 sweep true  OUT OF SPEC: tLOW1 45 us (sheet <= 15 us + a cycle)
       2400 50 us     designed 2400 sweep true  OUT OF SPEC: tLOW1 50 us (sheet <= 15 us + a cycle)
       2640 55 us     designed 2640 sweep true  OUT OF SPEC: tLOW1 55 us (sheet <= 15 us + a cycle)
    DS18B20 read sample
        336 7 us      designed 336 sweep true  in spec
        384 8 us      designed 384 sweep true  in spec
        432 9 us      designed 432 sweep true  in spec
        480 10 us     designed 480 sweep true  in spec
        528 11 us     designed 528 sweep true  in spec
        576 12 us     designed 576 sweep true  in spec
        624 13 us     designed 624 sweep true  in spec
        672 14 us     designed 672 sweep true  in spec
        720 15 us     designed 720 sweep true  OUT OF SPEC: read sample 15 us (sheet <= 15 us + a cycle)
        768 16 us     designed 768 sweep true  OUT OF SPEC: read sample 16 us (sheet <= 15 us + a cycle)
        816 17 us     designed 816 sweep true  OUT OF SPEC: read sample 17 us (sheet <= 15 us + a cycle)
        864 18 us     designed 864 sweep true  OUT OF SPEC: read sample 18 us (sheet <= 15 us + a cycle)
        912 19 us     designed 912 sweep true  OUT OF SPEC: read sample 19 us (sheet <= 15 us + a cycle)
        960 20 us     designed 960 sweep true  OUT OF SPEC: read sample 20 us (sheet <= 15 us + a cycle)
       1056 22 us     designed 1056 sweep true  OUT OF SPEC: read sample 22 us (sheet <= 15 us + a cycle)
       1152 24 us     designed 1152 sweep true  OUT OF SPEC: read sample 24 us (sheet <= 15 us + a cycle)
       1248 26 us     designed 1248 sweep true  OUT OF SPEC: read sample 26 us (sheet <= 15 us + a cycle)
       1344 28 us     designed 1344 sweep true  OUT OF SPEC: read sample 28 us (sheet <= 15 us + a cycle)
       1392 29 us     designed 1392 sweep true  OUT OF SPEC: read sample 29 us (sheet <= 15 us + a cycle)
       1440 30 us     designed 1440 sweep true  OUT OF SPEC: read sample 30 us (sheet <= 15 us + a cycle)
       1536 32 us     designed 1536 sweep true  OUT OF SPEC: read sample 32 us (sheet <= 15 us + a cycle)
       1632 34 us     designed 1632 sweep true  OUT OF SPEC: read sample 34 us (sheet <= 15 us + a cycle)
       1728 36 us     designed 1728 sweep true  OUT OF SPEC: read sample 36 us (sheet <= 15 us + a cycle)
       1824 38 us     designed 1824 sweep true  OUT OF SPEC: read sample 38 us (sheet <= 15 us + a cycle)
       1920 40 us     designed 1920 sweep true  OUT OF SPEC: read sample 40 us (sheet <= 15 us + a cycle)
       2160 45 us     designed 2160 sweep true  OUT OF SPEC: read sample 45 us (sheet <= 15 us + a cycle)
       2400 50 us     designed 2400 sweep true  OUT OF SPEC: read sample 50 us (sheet <= 15 us + a cycle)
       2640 55 us     designed 2640 sweep true  OUT OF SPEC: read sample 55 us (sheet <= 15 us + a cycle)
       2880 60 us     designed 2880 sweep true  OUT OF SPEC: read sample 60 us (sheet <= 15 us + a cycle)
    DS18B20 tREC
      21 ns: the kernel refuses it, line 128: this deadline wait can be reached 4 cycles late (slack -4..39)
      42 ns: the kernel refuses it, line 128: this deadline wait can be reached 3 cycles late (slack -3..39)
      83 ns: the kernel refuses it, line 128: this deadline wait can be reached 1 cycle late (slack -1..39)
          8 167 ns    designed 8 sweep true  OUT OF SPEC: tREC 167 ns (sheet >= 1 us + a cycle)
          9 188 ns    designed 9 sweep true  OUT OF SPEC: tREC 188 ns (sheet >= 1 us + a cycle)
         10 208 ns    designed 10 sweep true  OUT OF SPEC: tREC 208 ns (sheet >= 1 us + a cycle)
         11 229 ns    designed 11 sweep true  OUT OF SPEC: tREC 229 ns (sheet >= 1 us + a cycle)
         12 250 ns    designed 12 sweep true  OUT OF SPEC: tREC 250 ns (sheet >= 1 us + a cycle)
         16 333 ns    designed 16 sweep true  OUT OF SPEC: tREC 333 ns (sheet >= 1 us + a cycle)
         24 500 ns    designed 24 sweep true  OUT OF SPEC: tREC 500 ns (sheet >= 1 us + a cycle)
         32 667 ns    designed 32 sweep true  OUT OF SPEC: tREC 667 ns (sheet >= 1 us + a cycle)
         40 833 ns    designed 40 sweep true  OUT OF SPEC: tREC 833 ns (sheet >= 1 us + a cycle)
         48 1 us      designed 48 sweep true  OUT OF SPEC: tREC 1 us (sheet >= 1 us + a cycle)
         56 1.167 us  designed 56 sweep true  in spec
         72 1.5 us    designed 72 sweep true  in spec
         96 2 us      designed 96 sweep true  in spec
        144 3 us      designed 144 sweep true  in spec
        288 6 us      designed 288 sweep true  in spec
    DS18B20 tSLOT + tREC
      10 us: the kernel refuses it, line 128: this deadline wait can be reached 4 cycles late (slack -4..39)
        720 15 us     designed 720 sweep true  OUT OF SPEC: tLOW0 9 us (sheet >= 60 us + a cycle), tSLOT + tREC 15 us (sheet >= 61 us + a cycle)
        960 20 us     designed 960 sweep true  OUT OF SPEC: tLOW0 14 us (sheet >= 60 us + a cycle), tSLOT + tREC 20 us (sheet >= 61 us + a cycle)
       1200 25 us     designed 1200 sweep true  OUT OF SPEC: tLOW0 19 us (sheet >= 60 us + a cycle), tSLOT + tREC 25 us (sheet >= 61 us + a cycle)
       1440 30 us     designed 1440 sweep true  OUT OF SPEC: tLOW0 24 us (sheet >= 60 us + a cycle), tSLOT + tREC 30 us (sheet >= 61 us + a cycle)
       1488 31 us     designed 1488 sweep true  OUT OF SPEC: tLOW0 25 us (sheet >= 60 us + a cycle), tSLOT + tREC 31 us (sheet >= 61 us + a cycle)
       1536 32 us     designed 1536 sweep true  OUT OF SPEC: tLOW0 26 us (sheet >= 60 us + a cycle), tSLOT + tREC 32 us (sheet >= 61 us + a cycle)
       1584 33 us     designed 1584 sweep true  OUT OF SPEC: tLOW0 27 us (sheet >= 60 us + a cycle), tSLOT + tREC 33 us (sheet >= 61 us + a cycle)
       1632 34 us     designed 1632 sweep true  OUT OF SPEC: tLOW0 28 us (sheet >= 60 us + a cycle), tSLOT + tREC 34 us (sheet >= 61 us + a cycle)
       1680 35 us     designed 1680 sweep true  OUT OF SPEC: tLOW0 29 us (sheet >= 60 us + a cycle), tSLOT + tREC 35 us (sheet >= 61 us + a cycle)
       1920 40 us     designed 1920 sweep true  OUT OF SPEC: tLOW0 34 us (sheet >= 60 us + a cycle), tSLOT + tREC 40 us (sheet >= 61 us + a cycle)
       2160 45 us     designed 2160 sweep true  OUT OF SPEC: tLOW0 39 us (sheet >= 60 us + a cycle), tSLOT + tREC 45 us (sheet >= 61 us + a cycle)
       2400 50 us     designed 2400 sweep true  OUT OF SPEC: tLOW0 44 us (sheet >= 60 us + a cycle), tSLOT + tREC 50 us (sheet >= 61 us + a cycle)
       2640 55 us     designed 2640 sweep true  OUT OF SPEC: tLOW0 49 us (sheet >= 60 us + a cycle), tSLOT + tREC 55 us (sheet >= 61 us + a cycle)
       2880 60 us     designed 2880 sweep true  OUT OF SPEC: tLOW0 54 us (sheet >= 60 us + a cycle), tSLOT + tREC 60 us (sheet >= 61 us + a cycle)
       2928 61 us     designed 2928 sweep true  OUT OF SPEC: tLOW0 55 us (sheet >= 60 us + a cycle), tSLOT + tREC 61 us (sheet >= 61 us + a cycle)
       2976 62 us     designed 2976 sweep true  OUT OF SPEC: tLOW0 56 us (sheet >= 60 us + a cycle)
       3120 65 us     designed 3120 sweep true  OUT OF SPEC: tLOW0 59 us (sheet >= 60 us + a cycle)
       3456 72 us     designed 3456 sweep true  in spec
    |}]
;;
