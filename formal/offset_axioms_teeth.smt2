; offset_axioms.smt2's checks with one part wrong: each is sat.

; set x, v with v read as signed
(set-logic QF_BV)
(declare-const slope (_ BitVec 24))
(declare-const set_value (_ BitVec 5))
(assert (not (= (bvmul slope ((_ zero_extend 19) set_value))
                ((_ extract 23 0)
                 (bvmul ((_ sign_extend 6) slope) ((_ sign_extend 25) set_value))))))
(check-sat)
(reset)

; x-- with no guard on x
(set-logic QF_BV)
(declare-const x (_ BitVec 16))
(assert (not (= ((_ zero_extend 8) (bvsub x #x0001))
                (bvsub ((_ zero_extend 8) x) #x000001))))
(check-sat)
(reset)

; x-- with x read as signed
(set-logic QF_BV)
(declare-const x (_ BitVec 16))
(assert (not (= x #x0000)))
(assert (not (= ((_ sign_extend 8) (bvsub x #x0001))
                (bvsub ((_ sign_extend 8) x) #x000001))))
(check-sat)
(reset)

; x-- a slope back instead of further
(set-logic QF_BV)
(declare-const slope (_ BitVec 24))
(declare-const x (_ BitVec 24))
(declare-const phase (_ BitVec 24))
(declare-const phase_after (_ BitVec 24))
(assert (not (= (bvsub phase_after (bvmul slope (bvsub x #x000001)))
                (bvsub (bvadd (bvsub phase (bvmul slope x)) (bvsub phase_after phase))
                       slope))))
(check-sat-using (then (using-params simplify :som true) smt))
