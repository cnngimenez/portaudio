#lang racket/base

(require ffi/vector
         ffi/unsafe
         (rename-in racket/contract [-> c->])
         "portaudio.rkt"
         "devices.rkt"
         "callback-support.rkt")

;; this module provides a function that records a sound.

(define nat? exact-nonnegative-integer?)

(provide/contract [s16vec-record (c-> nat? integer? s16vector?)])

(define REASONABLE-LATENCY 0.1)
(define CHANNELS 2)

;; given a number of frames and a sample rate, record the sound
;; and return it. Blocks!
(define (s16vec-record frames sample-rate)
  (pa-maybe-initialize)
  (define copying-info (make-copying-info/rec frames))
  (define sr/i (exact->inexact sample-rate))
  (define device-number (find-output-device REASONABLE-LATENCY))
  (define device-latency (device-low-output-latency device-number)) 
  (define input-stream-parameters (make-pa-stream-parameters
                                   device-number
                                   CHANNELS
                                   '(paInt16)
                                   device-latency
                                   #f))
  
  (unless (default-device-has-stereo-input?)
    (error 's16vec-record
           "default input device does not support two-channel input"))
  
  (define stream
    (pa-open-stream
     input-stream-parameters ;; 
     #f             ;; output parameters
     sr/i          ;; sample rate
     0             ;;frames-per-buffer
     '(pa-clip-off)           ;; stream-flags
     copying-callback/rec ;; callback
     copying-info))
  ;;(pa-set-stream-finished-callback stream copying-info-free)
  (pa-start-stream stream)
  ;; need to figure out the "right" way to do this. Start with something crude:
  ;; some way to signal this directly? ... AH! use stream-finished-callback?
  (sleep (* frames (/ 1 sample-rate)))
  ;; (let loop ()
  ;;   (when (pa-stream-active? stream)
  ;;     (sleep 0.4)
  ;;     (loop)))
  (extract-recorded-sound copying-info))
