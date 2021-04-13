#lang racket
(require ffi/unsafe
         ffi/unsafe/define)

(define-ffi-definer define-winmm (ffi-lib "winmm.dll"))
(define-ffi-definer define-winmidi (ffi-lib "winmidi-wrapper.dll"))


(define _WORD _uint16)
(define _DWORD _uint32)
(define _HMIDIIN _pointer)
(define _MMVERSION _uint)
(define _MMRESULT
  (_enum '(MMSYSERR_NOERROR = 0
           MMSYSERR_ERROR = 1
           MMSYSERR_BADDEVICEID = 2
           MMSYSERR_NOTENABLED = 3
           MMSYSERR_ALLOCATED = 4
           MMSYSERR_INVALHANDLE = 5
           MMSYSERR_NODRIVER = 6
           MMSYSERR_NOMEM = 7
           MMSYSERR_NOTSUPPORTED = 8
           MMSYSERR_BADERRNUM = 9
           MMSYSERR_INVALFLAG = 10
           MMSYSERR_INVALPARAM = 11
           MMSYSERR_HANDLEBUSY = 12
           MMSYSERR_INVALIDALIAS = 13
           MMSYSERR_BADDB = 14
           MMSYSERR_KEYNOTFOUND = 15
           MMSYSERR_READERROR = 16
           MMSYSERR_WRITEERROR = 17
           MMSYSERR_DELETEERROR = 18
           MMSYSERR_VALNOTFOUND = 19
           MMSYSERR_NODRIVERCB = 20
           MMSYSERR_WAVERR_BADFORMAT = 32
           MMSYSERR_WAVERR_STILLPLAYING = 33
           MMSYSERR_WAVERR_UNPREPARED = 34)))
(define MAXPNAMELEN 32)


(define-cstruct _MIDIINCAPSA
  ([wMid _WORD]
   [wPid _WORD]
   [vDriverVersion _MMVERSION]
   [szPName (_array _byte MAXPNAMELEN)]
   [dwSupport _DWORD]))


(define-cstruct _MidiPacket
  ([Message _ubyte]
   [Channel _ubyte]
   [Data (_array _byte 2)]))


(define (check-mmresult result value)
  (unless (eq? result 'MMSYSERR_NOERROR) (error result))
  value)


(define-winmm midiInGetNumDevs (_fun -> _uint))


(define-winmm midiInGetDevCapsA
  (_fun (uDeviceID : _uint)
        (pmic : (_ptr o _MIDIINCAPSA))
        (cbmic : _uint = (ctype-sizeof _MIDIINCAPSA))
        -> (result : _MMRESULT)
        -> (check-mmresult result pmic)))


(define (midi-input-devices)
  (map
   (lambda (i) (list i (midiInGetDevCapsA i)))
   (range (midiInGetNumDevs))))


(define-winmidi OpenInput
  (_fun
   (port : _uint)
   -> (result : _MMRESULT)
   -> (check-mmresult result (void))))


(define-winmidi CloseInput
  (_fun
   (port : _uint)
   -> _void))


(define-winmidi PollInput
  (_fun
   (port : _uint)
   (packet : (_ptr o _MidiPacket))
   -> (result : _stdbool)
   -> (if result packet #f)))


(define (unpack-midi-packet packet)
  (list (MidiPacket-Message packet)
          (MidiPacket-Channel packet)
          (array-ref (MidiPacket-Data packet) 0)
          (array-ref (MidiPacket-Data packet) 1)))

(display (midi-input-devices))
(OpenInput 0)


;(define (wait)
;  (define (dispatch-event x) (when x (display (unpack-midi-packet x))))
;  (dispatch-event (PollInput 0))
;  (wait))
;(wait)