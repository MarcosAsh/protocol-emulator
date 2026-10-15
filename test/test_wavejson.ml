open! Core
open Protocol_emulator

let%expect_test "WaveDrom's relaxed syntax reads as the JSON it stands for" =
  let relaxed =
    {|{ signal: [
    // a clock and a level
    { name: 'clk', wave: 'p..', },
    ['group', { name: "q", wave: '01.', data: ['a', 'b'] }],
    {},
  ],
  /* ours */ table: { cycles: [20, 20, 20], },
}|}
  in
  let strict =
    {|{ "signal": [ { "name": "clk", "wave": "p.." },
  ["group", { "name": "q", "wave": "01.", "data": ["a", "b"] }], {} ],
  "table": { "cycles": [20, 20, 20] } }|}
  in
  let read s = Wavejson.parse s |> ok_exn in
  print_s [%message (read relaxed : Wavejson.t)];
  print_s
    [%message
      ""
        ~same:
          ([%equal: Wavejson.Value.t]
             (Wavejson.Value.parse relaxed |> ok_exn)
             (Wavejson.Value.parse strict |> ok_exn)
           : bool)];
  [%expect
    {|
    ("read relaxed"
     ((lanes
       (((name clk) (wave p..) (data ()) (input false) (phase 0) (period 1))
        ((name q) (wave 01.) (data (a b)) (input false) (phase 0) (period 1))))
      (cycles (Each (20 20 20))) (repeat ()) (words ())))
    (same true)
    |}]
;;
