# A teeth mutant of the netlist: the one LUT4 driving pad $pad's I pin turns into its
# inverse. Fails when no single LUT4 drives it, since the copy would then be no mutant.
.modules.icepi_top.cells[$pad].connections.I[0] as $net
| [.modules.icepi_top.cells | to_entries[]
   | select(.value.type == "LUT4" and .value.connections.Z[0] == $net) | .key] as $luts
| if ($luts | length) != 1 then error("flip.jq: no single LUT4 drives \($pad).I") else . end
| .modules.icepi_top.cells[$luts[0]].parameters.INIT
    |= (split("") | map(if . == "0" then "1" else "0" end) | join(""))
