; MIT License
;
; Copyright (c) 2016 Vincent Nys
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

#lang racket
(require cclp-common-data/abstract-multi-domain)
(require cclp-common-data/abstract-knowledge)
(require "data-utils.rkt"
         cclp-common-data/abstract-substitution)
(require (for-syntax syntax/parse))
(require racket/serialize)

(require scribble/srcdoc)



; note: can only substitute for an abstract variable, and there is never any reason to substitute an atom or conjunction for something, so use terms
;(: substitute-in-term (-> AbstractTerm AbstractVariable AbstractTerm AbstractTerm))
(define (substitute-in-term substituter substitutee input-elem)
  (match (list substituter substitutee input-elem)
    [(list _ (a i) (a j)) (if (equal? i j) substituter input-elem)]
    [(list _ (g i) (g j)) (if (equal? i j) substituter input-elem)]
    [(list _ t (abstract-function symbol args)) (abstract-function symbol (map (λ (a) (substitute-in-term substituter substitutee a)) args))]
    [else input-elem]))

;(: substitute-in-conjunct (-> AbstractTerm AbstractVariable abstract-atom abstract-atom))
(define (substitute-in-conjunct substituter substitutee input-conjunct)
  (match input-conjunct
    [(abstract-atom sym args) (abstract-atom sym (map (λ (a) (substitute-in-term substituter substitutee a)) args))]
    [(multi/annotations sm asc? rta)
     (multi/annotations (substitute-in-conjunct substituter substitutee sm) asc? rta)]
    [(simple-multi c1 i c2 f)
     (simple-multi c1 (map (match-lambda [(cons lhs rhs) (cons lhs (substitute-in-term substituter substitutee rhs))]) i) c2 (map (match-lambda [(cons lhs rhs) (cons lhs (substitute-in-term substituter substitutee rhs))]) f))]
    ))

;(: substitute-in-conjunction (-> AbstractTerm AbstractVariable AbstractConjunction AbstractConjunction))
(define (substitute-in-conjunction substituter substitutee conjunction) (map (λ (a) (substitute-in-conjunct substituter substitutee a)) conjunction))

;(: substitute-in-domain-elem (-> AbstractTerm AbstractVariable AbstractDomainElem AbstractDomainElem))
(define (substitute-in-domain-elem substituter substitutee elem)
  (cond [(abstract-atom? elem) (substitute-in-conjunct substituter substitutee elem)]
        [(abstract-term? elem) (substitute-in-term substituter substitutee elem)]
        [(list? elem) (substitute-in-conjunction substituter substitutee elem)]))

;(: substitute-in-substitution (-> AbstractTerm AbstractVariable AbstractSubstitution AbstractSubstitution))
(define (substitute-in-substitution substituter substitutee input-subst)
  (map (λ (aeq)
         (abstract-equality (substitute-in-domain-elem substituter substitutee (abstract-equality-term1 aeq))
                            (substitute-in-domain-elem substituter substitutee (abstract-equality-term2 aeq)))) input-subst))
(provide substitute-in-substitution)

; TODO can probably clean this up significantly now that this is no longer in TR

;(: apply-substitution-to-term (-> AbstractSubstitution AbstractTerm AbstractTerm))
(define (apply-substitution-to-term subst t)
  (foldl (λ (el acc)
           (substitute-in-term (abstract-equality-term2 el)
                               (abstract-equality-term1 el)
                               acc))
         t subst))
(provide apply-substitution-to-term)

; pretty much the same as applying to term - if I knew how to express a more flexible type, I could probably merge the two
;(: apply-substitution-to-conjunct (-> AbstractSubstitution AbstractConjunct AbstractConjunct))
(define (apply-substitution-to-conjunct subst t)
  (foldl (λ (el acc)
           (substitute-in-conjunct (abstract-equality-term2 el)
                                   (abstract-equality-term1 el)
                                   acc))
         t subst))
(provide apply-substitution-to-conjunct)

;(: apply-substitution-to-conjunction (-> AbstractSubstitution AbstractConjunction AbstractConjunction))
(define (apply-substitution-to-conjunction subst conjunction)
  (map (λ (conjunct) (apply-substitution-to-conjunct subst conjunct)) conjunction))
(provide apply-substitution-to-conjunction)

;(: apply-substitution-to-rule (-> AbstractSubstitution rule rule))
(define (apply-substitution-to-abstract-rule subst r)
  (abstract-rule (apply-substitution-to-conjunct subst (abstract-rule-head r)) (apply-substitution-to-conjunction subst (abstract-rule-body r))))

;(: apply-substitution-to-full-evaluation (-> AbstractSubstitution full-evaluation full-evaluation))
(define (apply-substitution-to-full-evaluation subst fe)
  (full-evaluation
   (apply-substitution-to-conjunct subst (full-evaluation-input-pattern fe))
   (apply-substitution-to-conjunct subst (full-evaluation-output-pattern fe))
   (full-evaluation-idx fe)))
(provide apply-substitution-to-full-evaluation)

(define (apply-substitution subst substitution-object)
  (cond [(abstract-term? substitution-object) (apply-substitution-to-term subst substitution-object)]
        [(abstract-conjunct? substitution-object) (apply-substitution-to-conjunct subst substitution-object)]
        [(list? substitution-object) (apply-substitution-to-conjunction subst substitution-object)]
        [(abstract-rule? substitution-object) (apply-substitution-to-abstract-rule subst substitution-object)]
        [(full-evaluation? substitution-object) (apply-substitution-to-full-evaluation subst substitution-object)]))
(provide
 (proc-doc/names
  apply-substitution
  (-> abstract-substitution?
      (or/c abstract-domain-elem*?
            abstract-knowledge?
            (listof abstract-conjunct?))
      (or/c abstract-domain-elem*?
            abstract-knowledge?
            (listof abstract-conjunct?)))
  (subst substitution-object)
  ("One documentation-time expression" "Another documentation-time expression")))

;(module+ test
;  (require rackunit)
;  (require "cclp-interpreter.rkt")
;  (require "abstraction-inspection-utils.rkt")
;  (check-equal? (substitute-in-substitution (interpret-abstract-term "g5") (interpret-abstract-term "a1") (list (abstract-equality (interpret-abstract-term "a4") (interpret-abstract-term "foo(bar(a3,a1,a2))"))))
;                (list (abstract-equality (interpret-abstract-term "a4") (interpret-abstract-term "foo(bar(a3,g5,a2))"))))
;  (check-equal? (substitute-in-substitution (interpret-abstract-term "g5") (interpret-abstract-term "a4") (list (abstract-equality (interpret-abstract-term "a4") (interpret-abstract-term "foo(bar(a3,a1,a2))"))))
;                (list (abstract-equality (interpret-abstract-term "g5") (interpret-abstract-term "foo(bar(a3,a1,a2))"))))
;  (check-equal? (apply-substitution-to-term (asubst ((g 1) quux) ((a 2) (g 4)))
;                                            (interpret-abstract-term "foo(bar(g1,a1),baz(g2,a2,a3))"))
;                (interpret-abstract-term "foo(bar(quux,a1),baz(g2,g4,a3))"))
;  (check-equal? (apply-substitution-to-conjunct (asubst ((g 1) quux) ((a 2) (g 4)))
;                                                (interpret-abstract-atom "foo(bar(g1,a1),baz(g2,a2,a3))"))
;                (interpret-abstract-atom "foo(bar(quux,a1),baz(g2,g4,a3))"))
;  (check-equal? (apply-substitution-to-conjunction (asubst ((g 1) quux) ((a 2) (g 4)))
;                                                   (list (interpret-abstract-atom "foo(bar(g1,a1),baz(g2,a2,a3))") (interpret-abstract-atom "zip(zoom(g1,a1),kweh(a2,g2,a5))")))
;                (list (interpret-abstract-atom "foo(bar(quux,a1),baz(g2,g4,a3))") (interpret-abstract-atom "zip(zoom(quux,a1),kweh(g4,g2,a5))")))
;  (check-equal? (apply-substitution-to-full-evaluation
;                 (asubst
;                  ((a 2) (a 16))
;                  ((a 1) (a 15))
;                  ((g 2) (g 21))
;                  ((g 1) (g 20)))
;                 (full-evaluation
;                  (interpret-abstract-atom "del(a1,[g1|g2],a2)")
;                  (interpret-abstract-atom "del(g3,[g1|g2],g4)")))
;                (full-evaluation
;                 (interpret-abstract-atom "del(a15,[g20|g21],a16)")
;                 (interpret-abstract-atom "del(g3,[g20|g21],g4)"))))