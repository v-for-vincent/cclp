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

#lang at-exp racket
(require cclp-common-data/abstract-knowledge
         cclp-common-data/abstract-multi-domain)
(require "data-utils.rkt")

(require scribble/srcdoc)
(require (for-doc scribble/manual))
(module+ test
  (require rackunit))

(define (assemble-var-indices right-variable-type? abstract-data)
  (define (assemble-aux right-variable-type? abstract-data)
    (match abstract-data
      [(? abstract-variable?)
       (if (right-variable-type? abstract-data)
           (list (avar-index abstract-data)) (list))]
      [(? abstract-atom?)
       (append* (map
                 (λ (arg) (assemble-var-indices right-variable-type? arg))
                 (abstract-atom-args abstract-data)))]
      [(? abstract-function?)
       (append*
        (map
         (λ (arg) (assemble-var-indices right-variable-type? arg))
         (abstract-function-args abstract-data)))]
      [(? list?)
       (append*
        (map (λ (arg) (assemble-var-indices right-variable-type? arg)) abstract-data))]
      [(? abstract-rule?)
       (append
        (assemble-var-indices right-variable-type? (abstract-rule-head abstract-data))
        (assemble-var-indices right-variable-type? (abstract-rule-body abstract-data)))]
      [(? full-evaluation?)
       (append
        (assemble-var-indices
         right-variable-type?
         (full-evaluation-input-pattern abstract-data))
        (assemble-var-indices
         right-variable-type?
         (full-evaluation-output-pattern abstract-data)))]
      [(simple-multi _ ic _ fc)
       (assemble-var-indices right-variable-type? (map cdr (append ic fc)))]
      [(multi/annotations sm _ _)
       (assemble-var-indices right-variable-type? sm)]))
  (remove-duplicates (assemble-aux right-variable-type? abstract-data)))
(provide
 (proc-doc/names
  assemble-var-indices
  (->
   (-> any/c boolean?)
   (or/c abstract-domain-elem*? abstract-rule? full-evaluation?)
   (listof exact-positive-integer?))
  (pred abstract-data)
  @{Assembles the indices of the variables for which @racket[pred] passes,
 at any level in @racket[abstract-data] and returns them in left-to-right order of occurrence,
 without any duplicates.}))
(module+ test
  (check-equal? (assemble-var-indices g? (a 1)) (list))
  (check-equal? (assemble-var-indices a? (g 1)) (list))
  ;(check-equal? (assemble-var-indices g? (interpret-abstract-term "foo(bar)")) (list))
  (check-equal? (assemble-var-indices g? (abstract-function 'bar (list))) (list))
  (check-equal?
   (assemble-var-indices g? (abstract-function 'bar (list (abstract-function 'bar'()))))
   (list))
  ;(check-equal? (assemble-var-indices a? (interpret-abstract-term "foo(bar)")) (list))
  ;(check-equal? (assemble-var-indices g? (interpret-abstract-term "foo(bar(g1,g2,a3,a4))")) (list 1 2))
  ;(check-equal? (assemble-var-indices a? (interpret-abstract-term "foo(bar(g1,g2,a3,a4))")) (list 3 4))
  ;(check-equal? (assemble-var-indices g? (interpret-abstract-atom "foo(bar(g1,g2,a3,a4))")) (list 1 2))
  ;(check-equal? (assemble-var-indices a? (interpret-abstract-atom "foo(bar(g1,g2,a3,a4))")) (list 3 4))

;  (check-equal?
;   (assemble-var-indices
;    g?
;    (list
;     (interpret-abstract-atom "foo(bar(g1,g2,a3,a4))")
;     (interpret-abstract-atom "foo(bar(g5,g6,a7,a8))")))
;   (list 1 2 5 6))
;  (check-equal?
;   (assemble-var-indices
;    a?
;    (list
;     (interpret-abstract-atom "foo(bar(g1,g2,a3,a4))")
;     (interpret-abstract-atom "foo(bar(g5,g6,a7,a8))")))
;   (list 3 4 7 8))

;  (check-equal?
;   (assemble-var-indices
;    a?
;    (full-evaluation (interpret-abstract-atom "del(a1,[g1|g2],a2)")
;                     (interpret-abstract-atom "del(g3,[g1|g2],g4)")
;                     1))
;   (list 1 2))
;  (check-equal?
;   (assemble-var-indices
;    g?
;    (full-evaluation (interpret-abstract-atom "del(a1,[g1|g2],a2)")
;                     (interpret-abstract-atom "del(g3,[g1|g2],g4)")
;                     1))
;   (list 1 2 3 4))
)

(define (maximum-var-index abstraction right-variable-type?)
  (define max-of-args-accumulator
    (λ (el acc)
      (let ([subterm-max (maximum-var-index el right-variable-type?)])
        (cond [(none? acc) subterm-max]
              [(none? subterm-max) acc]
              [else (some (max (some-v acc) (some-v subterm-max)))]))))
  (match abstraction
    [(? abstract-variable?)
     (if (right-variable-type? abstraction) (some (avar-index abstraction)) (none))]
    [(or (abstract-function sym args) (abstract-atom sym args))
     (foldl max-of-args-accumulator (none) args)]
    [(? list?)
     (foldl max-of-args-accumulator (none) abstraction)]
    [(? abstract-rule?)
     (maximum-var-index (cons (abstract-rule-head abstraction) (abstract-rule-body abstraction)) right-variable-type?)]
    [(? full-evaluation?)
     (maximum-var-index (list (full-evaluation-input-pattern abstraction) (full-evaluation-output-pattern abstraction)) right-variable-type?)]
    [(simple-multi _ ic _ fc)
     (maximum-var-index (map cdr (append ic fc)) right-variable-type?)]
    [(multi/annotations sm _ _)
     (maximum-var-index sm right-variable-type?)]))
(provide (contract-out [maximum-var-index (-> (or/c abstract-domain-elem*? abstract-knowledge?) (-> any/c boolean?) (maybe exact-nonnegative-integer?))]))

;(module+ test
;  (check-equal? (maximum-var-index (interpret-abstract-term "g1") g?) (some 1))
;  (check-equal? (maximum-var-index (interpret-abstract-term "g1") a?) (none))
;  (check-equal? (maximum-var-index (interpret-abstract-term "a2") a?) (some 2))
;  (check-equal? (maximum-var-index (interpret-abstract-term "a2") g?) (none))
;
;  (check-equal? (maximum-var-index (interpret-abstract-term "foo(g1,a2)") g?) (some 1))
;  (check-equal? (maximum-var-index (interpret-abstract-term "foo(g1,a2)") a?) (some 2))
;  (check-equal? (maximum-var-index (interpret-abstract-term "foo(g1,g2)") a?) (none))
;  (check-equal? (maximum-var-index (interpret-abstract-term "foo(a1,a2)") g?) (none))
;
;  (check-equal? (maximum-var-index (interpret-abstract-atom "foo(g1,a2)") g?) (some 1))
;  (check-equal? (maximum-var-index (interpret-abstract-atom "foo(g1,a2)") a?) (some 2))
;  (check-equal? (maximum-var-index (interpret-abstract-atom "foo(g1,g2)") a?) (none))
;  (check-equal? (maximum-var-index (interpret-abstract-atom "foo(a1,a2)") g?) (none)))

(define (contains-subterm? abstraction subterm)
  (match abstraction
    [(list) #f]
    [(list-rest h t) (ormap (λ (elem) (contains-subterm? elem subterm)) (cons h t))]
    [(abstract-atom sym args) (ormap (λ (arg) (contains-subterm? arg subterm)) args)]
    [(abstract-function sym args)
     (or (equal? abstraction subterm) (ormap (λ (arg) (contains-subterm? arg subterm)) args))]
    [other (equal? other subterm)]))
(provide
 (proc-doc/names
  contains-subterm?
  (-> abstract-domain-elem? abstract-term? boolean?)
  (abstraction subterm)
  @{Checks whether @racket[subterm] occurs anywhere in @racket[abstraction].}))

;(module+ test
;  (check-equal?
;   (contains-subterm? (interpret-abstract-conjunction "bar(a2),foo(q(g7),a1)") (g 7)) #t)
;  (check-equal?
;   (contains-subterm? (interpret-abstract-conjunction "bar(a2),foo(q(g7),a1)") (g 6)) #f))

(define (extract-all-variables/duplicates/base v exclude-constraints?)
  (define rec (λ (e) (extract-all-variables/duplicates/base e exclude-constraints?)))
  (match v
    [(list-rest h t)
     (append
      (rec h)
      (append-map rec t))]
    [(simple-multi conjunction ic cc fc)
     (append
      (append-map rec conjunction)
      (if
       exclude-constraints?
       empty
       (append
        (append-map (compose rec cdr) ic)
        (append-map (compose rec cdr) cc)
        (append-map (compose rec cdr) fc))))]
    [(multi/annotations sm _ _)
     (extract-all-variables/duplicates/base sm exclude-constraints?)]
    [(or
      (abstract-atom _ args)
      (abstract-function _ args)
      (abstract-atom* _ args)
      (abstract-function* _ args))
     (append-map rec args)]
    [(or
      (g _)
      (a _)
      (g* _ _ _)
      (a* _ _ _))
     (list v)]
    [_ empty]))

(define (extract-all-variables/duplicates/exclude-constraints v)
  (extract-all-variables/duplicates/base v #t))
(provide
 (proc-doc/names
  extract-all-variables/duplicates/exclude-constraints
  (->
   (or/c abstract-domain-elem*? abstract-variable*?)
   (listof (or/c abstract-variable? abstract-variable*?)))
  (v)
  @{Extracts all @racket[abstract-variable*] values in @racket[v] and returns them as a list,
 in order of occurrence. Unlike @racket[extract-all-variables/duplicates], this does not take into account variables with index i which occur in consecutive constraints.}))

(define (extract-all-variables/duplicates v)
  (extract-all-variables/duplicates/base v #f))
(provide
 (proc-doc/names
  extract-all-variables/duplicates
  (->
   (or/c abstract-domain-elem*? abstract-variable*?)
   (listof (or/c abstract-variable? abstract-variable*?)))
  (v)
  @{Extracts all @racket[abstract-variable*] values in @racket[v] and returns them as a list,
 in order of occurrence. Only takes into account local index i, not 1, i+1 or L.}))

(define (extract-subscripted-variables/duplicates v)
  (filter (λ (v) (abstract-variable*? v))
          (extract-all-variables/duplicates v)))
(provide
 (proc-doc/names
  extract-subscripted-variables/duplicates
  (->
   (or/c (listof abstract-conjunct?) multi? abstract-atom*? abstract-function*? a*? g*?)
   (listof (or/c a*? g*?)))
  (v)
  @{Extracts all @racket[abstract-variable*] values in @racket[v] and returns them as a list,
 in order of occurrence. Only takes into account local index i, not 1, i+1 or L.}))

;; used so generalization of level keeps multi ID's separate
;; only extracts from the pattern
(define (extract-subscripted-variables v)
  (remove-duplicates (extract-subscripted-variables/duplicates v)))
;(module+ test
;  (check-equal?
;   (extract-subscripted-variables
;    (multi (list
;            (abstract-atom* 'collect (list (g* 1 'i 1) (a* 1 'i 1)))
;            (abstract-atom* 'append (list (a* 1 'i 2) (a* 1 'i 1) (a* 1 'i 3))))
;           #t
;           empty
;           empty
;           empty))
;   (list (g* 1 'i 1) (a* 1 'i 1) (a* 1 'i 2) (a* 1 'i 3))))
(provide
 (proc-doc/names
  extract-subscripted-variables
  (->
   (or/c (listof abstract-conjunct?) multi? abstract-atom*? abstract-function*? a*? g*?)
   (listof (or/c a*? g*?)))
  (v)
  @{Like @racket[extract-subscripted-variables], but without duplicates.}))

(define (extract-variables/duplicates v)
  (filter
   (λ (v) (abstract-variable? v))
   (extract-all-variables/duplicates v)))
(provide
 (proc-doc/names
  extract-variables/duplicates
  (->
   (or/c (listof abstract-conjunct?) multi? abstract-atom? abstract-function? a? g?)
   (listof (or/c a? g?)))
  (v)
  @{Extracts all @racket[abstract-variable] values in @racket[v] and returns them as a list, in order of occurrence.}))

(define (extract-variables v)
  (remove-duplicates (extract-variables/duplicates v)))
(provide
 (proc-doc/names
  extract-variables
  (->
   (or/c (listof abstract-conjunct?) multi? abstract-atom? abstract-function? a? g?)
   (listof (or/c a? g?)))
  (v)
  @{Like @racket[extract-variables/duplicates], but without duplicates.}))

(define (get-multi-id m)
  (match m
    [(simple-multi patt _ _ _)
     (get-multi-id patt)]
    [(multi/annotations sm _ _)
     (get-multi-id sm)]
    [(list-rest h t)
     (or (get-multi-id h)
         (get-multi-id t))]
    [(or
      (abstract-atom* _ args)
      (abstract-function* _ args))
     #:when (not (null? args))
     (get-multi-id args)]
    [(or
      (abstract-atom* _ args)
      (abstract-function* _ args))
     #f]
    [(or
      (a* id _ _)
      (g* id _ _))
     id]))
(provide
 (proc-doc/names
  get-multi-id
  (-> multi? (or/c exact-positive-integer? #f))
  (m)
  @{Extracts the unique identifier from any @racket[abstract-variable*?] in @racket[m]}))

(define (extract-abstract-compounds v #:top [top? #t])
  (match v
    [(? list?)
     (append-map extract-abstract-compounds v)]
    [(or
      (abstract-atom _ args)
      (abstract-atom* _ args))
     (append-map extract-abstract-compounds args)]
    [(or
      (abstract-function _ args)
      (abstract-function* _ args))
     (list v)]
    [(simple-multi patt _ _ _)
     (append-map extract-abstract-compounds patt)]
    [(multi/annotations sm _ _)
     (extract-abstract-compounds sm)]
    [_ (list)]))
;(module+ test
;  (check-equal?
;   (extract-abstract-compounds
;    (interpret-abstract-conjunction "foo(bar(baz(nil)),quux),poit,narf(zorp(a1,g1))"))
;   (list
;    (interpret-abstract-term "bar(baz(nil))")
;    (abstract-function 'quux empty)
;    (abstract-function 'zorp (list (a 1) (g 1)))))
;  (check-equal?
;   (extract-abstract-compounds
;    (list
;     (multi
;      (list
;       (abstract-atom*
;        'foo
;        (list
;         (a* 1 'i 1)
;         (abstract-function*
;          'bar
;          (list
;           (abstract-function*
;            'baz
;            (list
;             (abstract-function*
;              'quux
;              empty)))
;           (g* 1 'i 1))))))
;      #t
;      (list
;        (cons (a* 1 'i 1) (abstract-function 'nil empty)))
;      empty
;      empty)))
;   (list
;    (abstract-function*
;       'bar
;       (list
;        (abstract-function*
;         'baz
;         (list
;          (abstract-function*
;           'quux
;           empty)))
;        (g* 1 'i 1))))))
(provide
 (proc-doc/names
  extract-abstract-compounds
  (->
   (listof abstract-conjunct?)
   (listof (or/c abstract-function? abstract-function*?)))
  (ac)
  @{Collects the top-level @racket[abstract-function?] and @racket[abstract-function*?] terms in @racket[ac].
 This function can contain duplicates and the compounds are in order of occurrence.
 Note that compounds which only occur in the constraint collections of a multi abstraction are not extracted.}))