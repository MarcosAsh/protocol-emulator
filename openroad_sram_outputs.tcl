# Put a buf_2 next to every SRAM data output, so the macro drives one input and stays under
# its 0.064 pF A_DOUT max_capacitance. Run by librelane_plugin_sram_outputs.py.
source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
source $::env(SCRIPTS_DIR)/openroad/common/resizer.tcl

read_current_odb
set_propagated_clock [all_clocks]
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl

set outputs {}
foreach inst [$::block getInsts] {
    if { ![string match RM_IHPSG13_* [[$inst getMaster] getName]] } {
        continue
    }
    foreach pin [get_pins [$inst getName]/*] {
        if { [get_property $pin direction] == "output"
             && [regexp {/A_DOUT} [get_full_name $pin]] } {
            lappend outputs $pin
        }
    }
}

set master [[ord::get_db] findMaster sg13cmos5l_buf_2]
foreach mterm [$master getMTerms] {
    if { [$mterm getSigType] == "SIGNAL" } {
        set port([$mterm getIoType]) [$mterm getName]
    }
}
set buffered 0
foreach pin $outputs {
    set iterm [$::block findITerm [get_full_name $pin]]
    set net [$iterm getNet]
    if { $net == "NULL" } {
        continue
    }
    set macro [[$iterm getInst] getBBox]
    lassign [$iterm getAvgXY] found x y
    set gap [expr { 2 * [$::block getDbUnitsPerMicron] }]
    if { $y - [$macro yMin] < [$macro yMax] - $y } {
        set y [expr { [$macro yMin] - 2 * $gap }]
    } else {
        set y [expr { [$macro yMax] + $gap }]
    }
    set buffer [odb::dbInst_create $::block $master "sram_output_buf_$buffered"]
    set wire [odb::dbNet_create $::block "sram_output_$buffered"]
    $iterm disconnect
    $iterm connect $wire
    [$buffer findITerm $port(INPUT)] connect $wire
    [$buffer findITerm $port(OUTPUT)] connect $net
    $buffer setLocation $x $y
    $buffer setPlacementStatus PLACED
    incr buffered
}
puts "\[INFO\] Buffered $buffered of [llength $outputs] SRAM outputs."
if { $buffered == 0 } {
    puts "\[ERROR\] Found no SRAM output to buffer."
    exit 1
}

source $::env(SCRIPTS_DIR)/openroad/common/dpl.tcl
if { $::env(GRT_DESIGN_REPAIR_RUN_GRT) } {
    source $::env(SCRIPTS_DIR)/openroad/common/grt.tcl
}

write_views
