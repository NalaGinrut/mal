;;  Copyright (C) 2015
;;      "Mu Lei" known as "NalaGinrut" <NalaGinrut@gmail.com>
;;  This file is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.

;;  This file is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.

;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

(library (core)
  (export core.ns ->list)
  (import (guile) (rnrs) (types) (reader) (printer) (ice-9 match) (readline)))

(define (->list o) ((if (vector? o) vector->list identity) o))

(define (_count obj)
  (cond
   ((_nil? obj) 0)
   ((vector? obj) (vector-length obj))
   (else (length obj))))

(define (_empty? obj) (zero? (_count obj)))

;; Well, strange spec...
(define (_equal? o1 o2)
  (equal? (->list o1) (->list o2)))

(define (pr-str . args)
  (define (pr x) (pr_str x #t))
  (string-join (map pr args) " "))

(define (str . args)
  (define (pr x) (pr_str x #f))
  (string-join (map pr args) ""))

(define (prn . args)
  (format #t "~a~%" (apply pr-str args))
  nil)

(define (println . args)
  (define (pr x) (pr_str x #f))
  (format #t "~{~a~^ ~}~%" (map pr args))
  nil)

(define (slurp filename)
  (when (not (file-exists? filename))
    (throw 'mal-error "File/dir doesn't exist" filename))
  (call-with-input-file filename get-string-all))

(define (_cons x y)
  (cons x (->list y)))

(define (concat . args)
  (apply append (map ->list args)))

(define (_nth lst n)
  (define ll (->list lst))
  (when (>= n (length ll))
    (throw 'mal-error "nth: index out of range"))
  (list-ref ll n))

(define (_first lst)
  (define ll (->list lst))
  (if (null? ll)
      nil
      (car ll)))

(define (_rest lst)
  (define ll (->list lst))
  (if (null? ll)
      '()
      (cdr ll)))

(define (_map f lst) (map (callable-closure f) (->list lst)))

(define (_apply f . args)
  (define ll
    (let lp((next (->list args)) (ret '()))
      (cond
       ((null? next) (reverse ret))
       (else
        (let ((n (->list (car next))))
          (lp (cdr next) (if (list? n)
                             (append (reverse n) ret)
                             (cons n ret))))))))
    (apply (callable-closure f) ll))

(define (->symbol x)
  ((if (symbol? x) identity string->symbol) x))

(define (->keyword x)
  ((if (_keyword? x) identity string->keyword) x))

(define* (list->hash-map lst #:optional (ht (make-hash-table)))
  (cond
   ((null? lst) ht)
   (else
    (let lp((next lst))
      (cond
       ((null? next) ht)
       (else
        (when (null? (cdr next))
          (throw 'mal-error
                 (format #f "hash-map: '~a' lack of value" (car next))))
        (let ((k (car next))
              (v (cadr next)))
          (hash-set! ht k v)
          (lp (cddr next)))))))))

(define (_hash-map . lst) (list->hash-map lst))

(define (_assoc ht . lst) (list->hash-map lst (hash-table-clone ht)))

(define (_get ht k)
  (if (_nil? ht)
      nil
      (hash-ref ht k nil)))

(define (_dissoc ht . lst)
  (define ht2 (hash-table-clone ht))
  (for-each (lambda (k) (hash-remove! ht2 k)) lst)
  ht2)

(define (_keys ht) (hash-map->list (lambda (k v) k) ht))

(define (_vals ht) (hash-map->list (lambda (k v) v) ht))

(define (_contains? ht k) (if (hash-ref ht k) #t #f))

(define (_sequential? o) (or (list? o) (vector? o)))

(define (_meta c)
  (if (callable? c)
      (callable-meta-info c)
      (or (object-property c 'meta) nil)))

(define (_with-meta c ht)
  (cond
   ((callable? c)
    (let ((cc (make-callable ht
                             (callable-unbox c)
                             (callable-is_macro c)
                             (callable-closure c))))
      cc))
   (else
    (let ((cc (box c)))
      (set-object-property! cc 'meta ht)
      cc))))

;; Apply closure 'c' with atom-val as one of arguments, then
;; set the result as the new val of atom. 
(define (_swap! atom c . rest)
  (let* ((args (cons (atom-val atom) rest))
         (val (callable-apply c args)))
    (atom-val-set! atom val)
    val))

(define (_conj lst . args)
  (cond
   ((vector? lst)
    (list->vector (append (->list lst) args)))
   ((list? lst)
    (append (reverse args) (->list lst)))
   (else (throw 'mal-error (format #f "conj: '~a' is not list/vector" lst)))))

(define *primitives*
  `((list        ,list)
    (list?       ,list?)
    (empty?      ,_empty?)
    (count       ,_count)
    (=           ,_equal?)
    (<           ,<)
    (<=          ,<=)
    (>           ,>)
    (>=          ,>=)
    (+           ,+)
    (-           ,-)
    (*           ,*)
    (/           ,/)
    (not         ,not)
    (pr-str      ,pr-str)
    (str         ,str)
    (prn         ,prn)
    (println     ,println)
    (read-string ,read_str)
    (slurp       ,slurp)
    (cons        ,_cons)
    (concat      ,concat)
    (nth         ,_nth)
    (first       ,_first)
    (rest        ,_rest)
    (map         ,_map)
    (apply       ,_apply)
    (nil?        ,_nil?)
    (true?       ,(lambda (x) (eq? x #t)))
    (false?      ,(lambda (x) (eq? x #f)))
    (symbol?     ,symbol?)
    (symbol      ,->symbol)
    (keyword     ,->keyword)
    (keyword?    ,_keyword?)
    (vector?     ,vector?)
    (vector      ,vector)
    (hash-map    ,_hash-map)
    (map?        ,hash-table?)
    (assoc       ,_assoc)
    (get         ,_get)
    (dissoc      ,_dissoc)
    (keys        ,_keys)
    (vals        ,_vals)
    (contains?   ,_contains?)
    (sequential? ,_sequential?)
    (readline    ,readline)
    (meta        ,_meta)
    (with-meta   ,_with-meta)
    (atom        ,make-atom)
    (deref       ,atom-val)
    (reset!      ,atom-val-set!)
    (swap!       ,_swap!)
    (conj        ,_conj)))

;; Well, we have to rename it to this strange name...
(define core.ns *primitives*)