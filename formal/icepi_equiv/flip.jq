# Teeth mutant of the netlist: invert the one LUT4 driving pad $pad's I pin. Fails if no
# single LUT4 drives it, because the copy would not be a mutant.
.modules.icepi_top.cells[$pad].connections.I[0] as $net
| [.modules.icepi_top.cells | to_entries[]
   | select(.value.type == "LUT4" and .value.connections.Z[0] == $net) | .key] as $luts
| if ($luts | length) != 1 then error("flip.jq: no single LUT4 drives \($pad).I") else . end
| .modules.icepi_top.cells[$luts[0]].parameters.INIT
    |= (split("") | map(if . == "0" then "1" else "0" end) | join(""))
