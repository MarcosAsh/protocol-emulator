"""
LibreLane plugin: buffer each SRAM data output next to the macro.

The resizer only sees the global-route estimate of an A_DOUT load, which undercounts the
routed net against the macro's 0.064 pF limit. ``src/config.json`` runs this after
Project.BufferSramInputs.
"""
import os

from librelane.steps import Step
from librelane.steps.openroad import RepairDesignPostGRT

HERE = os.path.dirname(os.path.abspath(__file__))


@Step.factory.register()
class BufferSramOutputs(RepairDesignPostGRT):
    id = "Project.BufferSramOutputs"
    name = "Buffer SRAM Outputs"

    def get_script_path(self):
        return os.path.join(HERE, "openroad_sram_outputs.tcl")
