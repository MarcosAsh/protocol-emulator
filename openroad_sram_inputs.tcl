# Buffer every SRAM signal input whose worst-corner slew on the global routes is over
# half the slow corner's 0.5952 ns max_transition, from a buf_2 next to the pin.
# Run by librelane_plugin_sram_inputs.py; the setup mirrors repair_design_postgrt.tcl.
source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
source $::env(SCRIPTS_DIR)/openroad/common/resizer.tcl

read_current_odb
set_propagated_clock [all_clocks]
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
source $::env(SCRIPTS_DIR)/openroad/common/grt.tcl
estimate_parasitics -global_routing

set max_slew 0.3
set inputs {}
foreach inst [$::block getInsts] {
    if { ![string match RM_IHPSG13_* [[$inst getMaster] getName]] } {
        continue
    }
    foreach pin [get_pins [$inst getName]/*] {
        if { [get_property $pin direction] == "input"
             && [regexp {/A_(ADDR|DIN|BM|MEN|WEN|REN)} [get_full_name $pin]] } {
            lappend inputs $pin
        }
    }
}

# a buf_2 just outside the macro edge nearest the pin, legalised below
set master [[ord::get_db] findMaster sg13cmos5l_buf_2]
foreach mterm [$master getMTerms] {
    if { [$mterm getSigType] == "SIGNAL" } {
        set port([$mterm getIoType]) [$mterm getName]
    }
}
set buffered 0
foreach pin $inputs {
    set slew [get_property $pin slew_max]
    if { $slew <= $max_slew } {
        continue
    }
    set iterm [$::block findITerm [get_full_name $pin]]
    set macro [[$iterm getInst] getBBox]
    lassign [$iterm getAvgXY] found x y
    set gap [expr { 2 * [$::block getDbUnitsPerMicron] }]
    if { $y - [$macro yMin] < [$macro yMax] - $y } {
        set y [expr { [$macro yMin] - 2 * $gap }]
    } else {
        set y [expr { [$macro yMax] + $gap }]
    }
    set net [$iterm getNet]
    set buffer [odb::dbInst_create $::block $master "sram_input_buf_$buffered"]
    set wire [odb::dbNet_create $::block "sram_input_$buffered"]
    $iterm disconnect
    $iterm connect $wire
    [$buffer findITerm $port(INPUT)] connect $net
    [$buffer findITerm $port(OUTPUT)] connect $wire
    $buffer setLocation $x $y
    $buffer setPlacementStatus PLACED
    puts "\[INFO\] Buffered [get_full_name $pin] at $slew ns."
    incr buffered
}
puts "\[INFO\] Buffered $buffered of [llength $inputs] SRAM inputs."

source $::env(SCRIPTS_DIR)/openroad/common/dpl.tcl
if { $::env(GRT_DESIGN_REPAIR_RUN_GRT) } {
    source $::env(SCRIPTS_DIR)/openroad/common/grt.tcl
}
estimate_parasitics -global_routing
foreach pin $inputs {
    set slew [get_property $pin slew_max]
    if { $slew > $max_slew } {
        puts "\[WARNING\] [get_full_name $pin] still at $slew ns."
    }
}

write_views
