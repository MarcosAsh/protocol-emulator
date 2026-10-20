open! Core
open! Hardcaml
module Edge = Kernel_types.Edge
module Spacing = Kernel_types.Spacing
module Spaced = Kernel_types.Spaced
module Loaded = Kernel_types.Loaded

module Make_timer (Timer : Engine.Timer) = struct
  include Kernel_types.Make_timer (Timer)
  module Kernel_step = Kernel_step.Make_timer (Timer)
  module Kernel_accepts = Kernel_accepts.Make_timer (Timer)
  module Make = Kernel_accepts.Make
  include Kernel_table.Make_timer (Timer)
  module I = Kernel_step.I
  module O = Step

  let hierarchical = Kernel_step.hierarchical

  module Accepts = Kernel_accepts.Accepts
end

include Make_timer (Isa)
