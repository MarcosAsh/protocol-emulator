"""
LibreLane plugin: buffer each SRAM input whose slew on the global routes is high.

The resizer models a load's slew in the driver's 20-80% terms, but the SRAM's
liberty measures 30-70% with a 0.5 derate, so OpenSTA reads 4/3 of it there and
a few a21oi_1-driven inputs signed off over the macro's max_transition.
``src/config.json`` runs this after the post-route timing repair.
"""
import os

from librelane.steps import Step
from librelane.steps.openroad import RepairDesignPostGRT

HERE = os.path.dirname(os.path.abspath(__file__))


@Step.factory.register()
class BufferSramInputs(RepairDesignPostGRT):
    id = "Project.BufferSramInputs"
    name = "Buffer SRAM Inputs"

    def get_script_path(self):
        return os.path.join(HERE, "openroad_sram_inputs.tcl")
