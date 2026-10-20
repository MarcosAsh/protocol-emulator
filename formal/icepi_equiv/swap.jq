# A teeth mutant of the netlist: pins $a and $b of the data memory's block RAM swap.
# Fails without that one block RAM.
[.modules.icepi_top.cells | to_entries[]
 | select(.value.type == "DP16KD" and (.key | contains(".data_memory."))) | .key] as $rams
| if ($rams | length) != 1 then error("swap.jq: no single data memory block RAM") else . end
| .modules.icepi_top.cells[$rams[0]].connections
    |= (.[$a] as $bit | .[$a] = .[$b] | .[$b] = $bit)
