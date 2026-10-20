; The axioms row_step.sv, phase_step.sv's AFFINE run and test_kernel.ml put on the free
; offsets hold of the true ones, phase - slope * x modulo 2^24 with x unsigned: each
; check is unsat. x-- goes in two steps, the 16-bit decrement as a 24-bit one where x is
; not 0, then the ring identity, which z3 normalises as a polynomial. Each check starts
; afresh, as z3 solves incremental queries without its bit-vector preprocessing.

; after set x, v: phase' less the product row_step takes, slope * {1'b0, v} in 30 bits
(set-logic QF_BV)
(declare-const slope (_ BitVec 24))
(declare-const set_value (_ BitVec 5))
(assert (not (= (bvmul slope ((_ zero_extend 19) set_value))
                ((_ extract 23 0)
                 (bvmul ((_ sign_extend 6) slope) ((_ zero_extend 25) set_value))))))
(check-sat)
(reset)

; x and the slope the same: the offset moves as the phase does
(set-logic QF_BV)
(declare-const slope (_ BitVec 24))
(declare-const x (_ BitVec 16))
(declare-const phase (_ BitVec 24))
(declare-const phase_after (_ BitVec 24))
(define-fun product () (_ BitVec 24) (bvmul slope ((_ zero_extend 8) x)))
(assert (not (= (bvsub phase_after product)
                (bvadd (bvsub phase product) (bvsub phase_after phase)))))
(check-sat)
(reset)

; x-- where x is not 0, as a 24-bit decrement
(set-logic QF_BV)
(declare-const x (_ BitVec 16))
(assert (not (= x #x0000)))
(assert (not (= ((_ zero_extend 8) (bvsub x #x0001))
                (bvsub ((_ zero_extend 8) x) #x000001))))
(check-sat)
(reset)

; and then the offset moves a slope further, for any x of 24 bits
(set-logic QF_BV)
(declare-const slope (_ BitVec 24))
(declare-const x (_ BitVec 24))
(declare-const phase (_ BitVec 24))
(declare-const phase_after (_ BitVec 24))
(assert (not (= (bvsub phase_after (bvmul slope (bvsub x #x000001)))
                (bvadd (bvsub phase (bvmul slope x)) (bvsub phase_after phase) slope))))
(check-sat-using (then (using-params simplify :som true) smt))
(reset)

; x 0: no product
(set-logic QF_BV)
(declare-const slope (_ BitVec 24))
(assert (not (= (bvmul slope ((_ zero_extend 8) #x0000)) #x000000)))
(check-sat)
