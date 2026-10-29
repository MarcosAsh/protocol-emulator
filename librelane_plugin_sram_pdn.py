"""
LibreLane plugin: rewrite Metal4 PDN stripes onto the IHP SRAM's power columns.

LibreLane imports modules named ``librelane_plugin_*`` from the repository root
(librelane/plugins.py). ``src/config.json`` inserts the step:

    "meta": {
      "substituting_steps": {
        "+OpenROAD.GeneratePDN": "Project.ExtendPowerStripes"
      }
    }
"""
import os

from librelane.steps import Step
from librelane.steps.odb import OdbpyStep

HERE = os.path.dirname(os.path.abspath(__file__))


@Step.factory.register()
class ExtendPowerStripes(OdbpyStep):
    id = "Project.ExtendPowerStripes"
    name = "Extend Power Stripes Over SRAM"

    def get_script_path(self):
        return os.path.join(HERE, "odb_sram_stripes.py")


# netgen writes IHP SRAM pin names into its LVS JSON with a stray backslash ("\VDD!"),
# an invalid JSON escape that kills librelane's LVS step. As in ihp-um-janestreet-prism.
import json as _json
import re as _re
import types as _types

import librelane.steps.netgen as _netgen

_BAD_ESCAPE = _re.compile(r'\\(\\|[^"\\/bfnrtu])')


def _repair_escapes(s):
    return _BAD_ESCAPE.sub(
        lambda m: '\\\\' if m.group(1) == '\\' else '\\\\' + m.group(1), s
    )


def _loads_repairing_escapes(s, *args, **kwargs):
    try:
        return _json.loads(s, *args, **kwargs)
    except _json.JSONDecodeError:
        return _json.loads(_repair_escapes(s), *args, **kwargs)


_netgen.json = _types.SimpleNamespace(
    loads=_loads_repairing_escapes,
    load=_json.load,
    dumps=_json.dumps,
    dump=_json.dump,
    JSONDecodeError=_json.JSONDecodeError,
)
