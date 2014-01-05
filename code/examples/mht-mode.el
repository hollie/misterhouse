
;; emacs major mode for editing mht files as used by misterhouse.

(define-generic-mode 'mht-mode
      '("#")
      '("SCENE_MEMBER"
	"XPL_SENSOR"

	;; Insteon
	"INSTEON_PLM"
	"INSTEON_LAMPLINC"
	"INSTEON_APPLIANCELINC"
        "INSTEON_SWITCHLINC"
	"INSTEON_SWITCHLINCRELAY"
	"INSTEON_KEYPADLINC"
	"INSTEON_KEYPADLINCRELAY"
	"INSTEON_REMOTELINC"
	"INSTEON_MOTIONSENSOR"
	"INSTEON_IOLINC"
	"INSTEON_FANLINC"
	"INSTEON_ICONTROLLER"
	"INSTEON_THERMOSTAT"
	"INSTEON_IRRIGATION"

	;; LOMP
	"LIGHT"
	"OCCUPANCY"
	"MOTION"
	"PRESENCE"
         )
      '(("[[:xdigit:]]\\{2\\}\\.[[:xdigit:]]\\{2\\}\\.[[:xdigit:]]\\{2\\}\\:?\\([[:digit:]]\\{2\\}\\)?" . 'font-lock-variable-name-face)           ;; addresses
        ("[[:digit:]]+\\%" . 'font-lock-constant-face)    ;; on level
        ("[\\.[:digit:]]+s" . 'font-lock-constant-face))  ;; ramp rate
      '(".mht\\'")
      nil
      "Major mode for editing mht files as used by misterhouse."
)
