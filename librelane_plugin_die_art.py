"""
LibreLane plugin: draw the carrier board's cat (die_art.py) into the Metal4 routing
obstruction after stream out, so KLayout DRC, the render and precheck all see it.
``src/config.json`` inserts it with ``"+KLayout.StreamOut": "Project.DieArt"``.
"""
import os
import sys

from librelane.common import Path
from librelane.state import DesignFormat
from librelane.steps import Step, StepError
from librelane.steps.klayout import KLayoutStep
from librelane.steps.odb import AddRoutingObstructions

HERE = os.path.dirname(os.path.abspath(__file__))


@Step.factory.register()
class DieArt(KLayoutStep):
    id = "Project.DieArt"
    name = "Draw Die Art"

    inputs = [DesignFormat.GDS]
    outputs = [DesignFormat.GDS]
    config_vars = KLayoutStep.config_vars + AddRoutingObstructions.config_vars

    def run(self, state_in, **kwargs):
        boxes = [
            box for layer, *box in self.config["ROUTING_OBSTRUCTIONS"] or [] if layer == "Metal4"
        ]
        if len(boxes) != 1:
            raise StepError("die art wants exactly one Metal4 routing obstruction to draw in")
        output = os.path.join(self.step_dir, f"{self.config['DESIGN_NAME']}.gds")
        kwargs, env = self.extract_env(kwargs)
        self.run_pya_script(
            [
                sys.executable,
                os.path.join(HERE, "die_art.py"),
                str(state_in[DesignFormat.GDS]),
                output,
                "--box",
                *map(str, boxes[0]),
            ],
            env=env,
        )
        return {DesignFormat.GDS: Path(output)}, {}
