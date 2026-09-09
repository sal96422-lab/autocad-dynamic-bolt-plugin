;;; ImperialBoltBlock.lsp
;;; Places the supplied configurable metric hex-bolt block in side elevation.
;;; Units: millimetres.  Command: IBOLT

(if (null *ibolt-unit*) (setq *ibolt-unit* "Metric"))
(if (null *ibolt-metric-index*) (setq *ibolt-metric-index* "1"))
(if (null *ibolt-imperial-index*) (setq *ibolt-imperial-index* "2"))

(defun ib:line (p1 p2)
  (entmake
    (list '(0 . "LINE") '(100 . "AcDbEntity") '(8 . "0")
          '(62 . 0) '(6 . "BYBLOCK") '(100 . "AcDbLine")
          (cons 10 p1) (cons 11 p2))))

(defun ib:head-size (d / sizes hit)
  ;; Nominal diameter, width across flats, head thickness (ASME-style sizes).
  (setq sizes
    '((0.2500 0.4375 0.1630) (0.3125 0.5000 0.2110)
      (0.3750 0.5625 0.2430) (0.4375 0.6250 0.2910)
      (0.5000 0.7500 0.3230) (0.5625 0.8125 0.3710)
      (0.6250 0.9375 0.4030) (0.7500 1.1250 0.4830)
      (0.8750 1.3125 0.5630) (1.0000 1.5000 0.6270)))
  (foreach row sizes
    (if (< (abs (- d (car row))) 0.0001) (setq hit row)))
  (if hit
    (cdr hit)
    (list (* 1.5 d) (* 0.65 d))))

(defun ib:num-tag (x / s)
  (setq s (rtos x 2 4))
  (while (= "0" (substr s (strlen s) 1))
    (setq s (substr s 1 (1- (strlen s)))))
  (if (= "." (substr s (strlen s) 1))
    (setq s (substr s 1 (1- (strlen s)))))
  (vl-string-translate "." "p" s))

(defun ib:choose-size (/ file dcl result)
  (setq file (findfile "ibolt.dcl"))
  (if (null file)
    nil
    (progn
      (setq dcl (load_dialog file))
      (if (not (new_dialog "ibolt_size" dcl))
        (progn (unload_dialog dcl) nil)
        (progn
          (start_list "metric_size")
          (mapcar 'add_list
            '("M16  -  16.00 mm" "M20  -  20.00 mm"
              "M22  -  22.00 mm" "M24  -  24.00 mm"
              "M27  -  27.00 mm" "M30  -  30.00 mm"
              "M36  -  36.00 mm"))
          (end_list)
          (start_list "imperial_size")
          (mapcar 'add_list
            '("1/2\"  -  12.70 mm" "5/8\"  -  15.88 mm"
              "3/4\"  -  19.05 mm" "7/8\"  -  22.23 mm"
              "1\"  -  25.40 mm" "1-1/8\"  -  28.58 mm"
              "1-1/4\"  -  31.75 mm" "1-1/2\"  -  38.10 mm"))
          (end_list)
          (set_tile "metric_size" *ibolt-metric-index*)
          (set_tile "imperial_size" *ibolt-imperial-index*)
          (if (= *ibolt-unit* "Imperial")
            (progn
              (set_tile "imperial" "1")
              (mode_tile "metric_size" 1)
              (mode_tile "imperial_size" 0))
            (progn
              (set_tile "metric" "1")
              (mode_tile "metric_size" 0)
              (mode_tile "imperial_size" 1)))
          (action_tile "metric"
            "(setq *ibolt-unit* \"Metric\") (mode_tile \"metric_size\" 0) (mode_tile \"imperial_size\" 1)")
          (action_tile "imperial"
            "(setq *ibolt-unit* \"Imperial\") (mode_tile \"metric_size\" 1) (mode_tile \"imperial_size\" 0)")
          (action_tile "metric_size"
            "(setq *ibolt-metric-index* $value)")
          (action_tile "imperial_size"
            "(setq *ibolt-imperial-index* $value)")
          (action_tile "accept" "(done_dialog 1)")
          (action_tile "cancel" "(done_dialog 0)")
          (setq result (start_dialog))
          (unload_dialog dcl)
          (if (= result 1)
            (list *ibolt-unit* *ibolt-metric-index* *ibolt-imperial-index*)
            nil))))))

(defun ib:set-dynamic-length (ename required-length / obj props prop pname
                                    value ptype xscale target changed)
  (setq changed nil
        obj (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
  (if (and (not (vl-catch-all-error-p obj))
           (vlax-property-available-p obj 'IsDynamicBlock)
           (= :vlax-true (vla-get-IsDynamicBlock obj)))
    (progn
      (setq props (vlax-invoke obj 'GetDynamicBlockProperties)
            xscale (abs (vla-get-XScaleFactor obj)))
      (if (< xscale 1e-9) (setq xscale 1.0))
      (setq target (/ required-length xscale))
      (foreach prop props
        (setq pname (strcase (vla-get-PropertyName prop)))
        (if (and (not changed)
                 (= :vlax-false (vla-get-ReadOnly prop))
                 (or (vl-string-search "DISTANCE" pname)
                     (vl-string-search "LENGTH" pname)))
          (progn
            (setq value (vla-get-Value prop)
                  ptype (vlax-variant-type value))
            (if (member ptype '(2 3 5))
              (progn
                (vla-put-Value prop (vlax-make-variant target ptype))
                (setq changed T))))))))
  changed)

(defun ib:set-dynamic-grip (ename grip-mm diameter-mm
                            / obj props prop pname value ptype target changed)
  ;; Legacy direct Grip setter retained for compatibility. The calibrated
  ;; setter below is used by IBOLT because BOLT19 includes a hidden offset.
  (setq changed nil
        target (/ grip-mm diameter-mm)
        obj (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
  (if (not (vl-catch-all-error-p obj))
    (progn
      (setq props (vlax-invoke obj 'GetDynamicBlockProperties))
      (foreach prop props
        (setq pname (strcase (vla-get-PropertyName prop)))
        (if (and (not changed)
                 (= pname "GRIP")
                 (= :vlax-false (vla-get-ReadOnly prop)))
          (progn
            (setq value (vla-get-Value prop)
                  ptype (vlax-variant-type value))
            (vla-put-Value prop (vlax-make-variant target ptype))
            (setq changed T))))))
  changed)

(defun ib:measure-nut-face (obj origin ang
                            / exploded item rng items sorted runmax gap bestgap
                              split ux uy)
  ;; Explode a temporary copy of the dynamic reference, measure the first face
  ;; of the nut beyond the largest axial gap, then erase the temporary geometry.
  (setq exploded (vl-catch-all-apply 'vlax-invoke (list obj 'Explode)))
  (if (vl-catch-all-error-p exploded)
    nil
    (progn
      (setq ux (cos ang) uy (sin ang) items nil)
      (foreach item exploded
        (if (vlax-method-applicable-p item 'GetBoundingBox)
          (progn
            (setq rng (ib:projected-range item origin ux uy))
            (setq items (cons (list (car rng) (cadr rng) item) items)))))
      (setq sorted (vl-sort items '(lambda (a b) (< (car a) (car b))))
            runmax (if sorted (cadar sorted) 0.0)
            bestgap -1.0
            split nil)
      (foreach item (cdr sorted)
        (setq gap (- (car item) runmax))
        (if (> gap bestgap)
          (setq bestgap gap split (car item)))
        (setq runmax (max runmax (cadr item))))
      (foreach item exploded (vla-Delete item))
      (if (and split (> bestgap 0.0)) split nil))))

(defun ib:calibrate-dynamic-grip (ename origin ang required-length
                                  / obj props prop pname value ptype g0 g1
                                    m0 m1 step slope target result p)
  (setq result nil
        obj (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
  (if (not (vl-catch-all-error-p obj))
    (progn
      (setq props (vlax-invoke obj 'GetDynamicBlockProperties)
            prop nil)
      (foreach p props
        (if (= "GRIP" (strcase (vla-get-PropertyName p))) (setq prop p)))
      (if prop
        (progn
          (setq value (vla-get-Value prop)
                ptype (vlax-variant-type value)
                g0 (vlax-variant-value value)
                m0 (ib:measure-nut-face obj origin ang))
          (if m0
            (progn
              ;; Measure how far the nut actually moves per Grip unit. This
              ;; automatically accounts for BOLT19's hidden origin offset.
              (setq step 0.25)
              (vla-put-Value prop (vlax-make-variant (+ g0 step) ptype))
              (vla-Update obj)
              (setq g1 (vlax-variant-value (vla-get-Value prop))
                    m1 (ib:measure-nut-face obj origin ang))
              (if (and m1 (> (abs (- g1 g0)) 1e-9)
                       (> (abs (- m1 m0)) 1e-9))
                (progn
                  (setq slope (/ (- m1 m0) (- g1 g0))
                        target (+ g0 (/ (- required-length m0) slope)))
                  (vla-put-Value prop (vlax-make-variant target ptype))
                  (vla-Update obj)
                  (setq result T))
                (progn
                  (vla-put-Value prop (vlax-make-variant g0 ptype))
                  (vla-Update obj)))))))))
  result)

(defun ib:projected-range (obj origin ux uy / mn mx a b pts vals)
  (vla-GetBoundingBox obj 'mn 'mx)
  (setq a (vlax-safearray->list mn)
        b (vlax-safearray->list mx)
        pts (list (list (car a) (cadr a))
                  (list (car a) (cadr b))
                  (list (car b) (cadr a))
                  (list (car b) (cadr b)))
        vals
          (mapcar
            '(lambda (p)
               (+ (* (- (car p) (car origin)) ux)
                  (* (- (cadr p) (cadr origin)) uy)))
            pts))
  (list (apply 'min vals) (apply 'max vals)))

(defun ib:place-nut-at-end (ename origin ang required-length
                            / obj exploded items item rng sorted runmax gap
                              bestgap split nutitems nutmin delta vec ux uy)
  (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
  (if (vl-catch-all-error-p obj)
    nil
    (progn
      ;; Explode the supplied dynamic assembly into its bolt and nut graphics.
      (setq exploded (vl-catch-all-apply 'vlax-invoke (list obj 'Explode)))
      (if (vl-catch-all-error-p exploded)
        nil
        (progn
          (vla-Delete obj)
          (setq ux (cos ang)
                uy (sin ang)
                items nil)
          (foreach item exploded
            (if (vlax-method-applicable-p item 'GetBoundingBox)
              (progn
                (setq rng (ib:projected-range item origin ux uy))
                (setq items (cons (list (car rng) (cadr rng) item) items)))))
          (setq sorted (vl-sort items '(lambda (a b) (< (car a) (car b))))
                runmax (cadar sorted)
                bestgap -1.0
                split nil)
          ;; The clear gap between the bolt tip and nut is the largest empty
          ;; interval along the assembly axis.
          (foreach item (cdr sorted)
            (setq gap (- (car item) runmax))
            (if (> gap bestgap)
              (setq bestgap gap
                    split (car item)))
            (setq runmax (max runmax (cadr item))))
          (if (or (null split) (<= bestgap 0.0))
            nil
            (progn
              (setq nutitems
                (vl-remove-if '(lambda (x) (< (car x) (- split 1e-6))) sorted)
                    nutmin (apply 'min (mapcar 'car nutitems))
                    delta (- required-length nutmin)
                    vec (vlax-3d-point (list (* delta ux) (* delta uy) 0.0)))
              (foreach item nutitems
                (vla-Move (caddr item) (vlax-3d-point '(0.0 0.0 0.0)) vec))
              T)))))))

(defun ib:make-block (name d len thd / hs af hh ht x0 x1 pitch x)
  (setq hs (ib:head-size d)
        af (car hs)
        ht (cadr hs)
        hh (/ d 2.0)
        x0 (- ht)
        x1 (- len thd))

  (entmake
    (list '(0 . "BLOCK") '(100 . "AcDbEntity") '(8 . "0")
          '(100 . "AcDbBlockBegin") (cons 2 name) (cons 70 0)
          (cons 10 '(0.0 0.0 0.0))))

  ;; Hex head in side elevation, with conventional chamfer lines.
  (ib:line (list x0 (- (/ af 2.0)) 0.0) (list 0.0 (- (/ af 2.0)) 0.0))
  (ib:line (list 0.0 (- (/ af 2.0)) 0.0) (list 0.0 (/ af 2.0) 0.0))
  (ib:line (list 0.0 (/ af 2.0) 0.0) (list x0 (/ af 2.0) 0.0))
  (ib:line (list x0 (/ af 2.0) 0.0) (list x0 (- (/ af 2.0)) 0.0))
  (ib:line (list (+ x0 (* 0.18 ht)) (- (/ af 2.0)) 0.0)
           (list x0 (- (* 0.32 af)) 0.0))
  (ib:line (list x0 (* 0.32 af) 0.0)
           (list (+ x0 (* 0.18 ht)) (/ af 2.0) 0.0))

  ;; Shank and chamfered end.
  (ib:line (list 0.0 hh 0.0) (list (- len (* 0.12 d)) hh 0.0))
  (ib:line (list 0.0 (- hh) 0.0) (list (- len (* 0.12 d)) (- hh) 0.0))
  (ib:line (list (- len (* 0.12 d)) hh 0.0) (list len (* 0.34 d) 0.0))
  (ib:line (list len (* 0.34 d) 0.0) (list len (- (* 0.34 d)) 0.0))
  (ib:line (list len (- (* 0.34 d)) 0.0)
           (list (- len (* 0.12 d)) (- hh) 0.0))

  ;; Thread runout and conventional thread strokes.
  (if (> thd 0.0)
    (progn
      (ib:line (list x1 hh 0.0) (list (+ x1 (* 0.18 d)) (- hh) 0.0))
      (setq pitch (max 0.08 (* 0.22 d))
            x (+ x1 (* 0.18 d)))
      (while (< x (- len (* 0.08 d)))
        (ib:line (list x hh 0.0)
                 (list (min (+ x (* 0.32 d)) len) (- hh) 0.0))
        (setq x (+ x pitch)))))

  ;; Centerline geometry uses BYBLOCK linetype unless the host drawing overrides it.
  (entmake
    (list '(0 . "LINE") '(100 . "AcDbEntity") '(8 . "0")
          '(62 . 0) '(6 . "BYBLOCK") '(100 . "AcDbLine")
          (cons 10 (list (- x0 (* 0.25 d)) 0.0 0.0))
          (cons 11 (list (+ len (* 0.25 d)) 0.0 0.0))))

  (entmake '((0 . "ENDBLK") (100 . "AcDbEntity") (8 . "0")
             (100 . "AcDbBlockEnd"))))

(defun c:IBOLT (/ *error* oldecho edge-start edge-end assembly-length d ip ang
                  unit-mode scale-factor unit-label size-label metric-size
                  imperial-size imperial-row imperial-map source insert-name
                  inserted dynamic-ref grip-set size-choice size-index
                  metric-values imperial-values)
  (setq oldecho (getvar "CMDECHO"))
  (defun *error* (msg)
    (setvar "CMDECHO" oldecho)
    (if (and msg (/= msg "Function cancelled"))
      (princ (strcat "\nIBOLT error: " msg)))
    (princ))
  (setvar "CMDECHO" 0)

  ;; Pick the two opposite plate faces.  Their separation is the grip distance
  ;; between the underside of the bolt head and the inside face of the nut.
  (setq edge-start
    (getpoint "\nStep 1 of 2 - Pick the plate face under the bolt head: "))
  (if (null edge-start)
    (progn
      (setvar "CMDECHO" oldecho)
      (princ "\nNo first plate face selected.")
      (exit)))
  (setq edge-end
    (getpoint edge-start
      "\nStep 2 of 2 - Pick the opposite plate face beside the nut: "))
  (if (null edge-end)
    (progn
      (setvar "CMDECHO" oldecho)
      (princ "\nNo second plate face selected.")
      (exit)))
  (setq ip edge-end
        ang (angle edge-start edge-end)
        assembly-length (distance edge-start edge-end)
        ip edge-start)

  (setq size-choice (ib:choose-size))
  (if (null size-choice)
    (progn
      (setvar "CMDECHO" oldecho)
      (princ "\nBolt placement cancelled.")
      (exit)))
  (setq unit-mode (car size-choice)
        metric-values
          '(("M16" 16.00) ("M20" 20.00) ("M22" 22.00)
            ("M24" 24.00) ("M27" 27.00) ("M30" 30.00)
            ("M36" 36.00))
        imperial-values
          '(("1/2" 12.70) ("5/8" 15.88) ("3/4" 19.05)
            ("7/8" 22.23) ("1" 25.40) ("1-1/8" 28.58)
            ("1-1/4" 31.75) ("1-1/2" 38.10)))
  (if (= unit-mode "Imperial")
    (progn
      (setq size-index (atoi (caddr size-choice))
            imperial-row (nth size-index imperial-values)
            imperial-size (car imperial-row)
            d (cadr imperial-row)
            scale-factor (/ d 19.05)
            unit-label " mm nominal"
            size-label (strcat imperial-size "\"")))
    (progn
      (setq size-index (atoi (cadr size-choice))
            imperial-row (nth size-index metric-values)
            metric-size (car imperial-row)
            d (cadr imperial-row)
            size-label metric-size
            unit-label " mm nominal"
            scale-factor (/ d 19.05))))

  ;; The supplied DWG contains a 3/4-inch (19.05 mm) nominal BOLT19 block.
  ;; Insert the DWG as an outer block, scale it by requested diameter, then
  ;; explode only that wrapper so the original dynamic BOLT19 reference remains.
  (setq source (findfile "IBOLT_SOURCE_V2.dwg")
        insert-name "IBOLT_SOURCE_V2")
  (if (null source)
    (progn
      (setvar "CMDECHO" oldecho)
      (princ "\nIBOLT_SOURCE_V2.dwg was not found in the AutoCAD support path.")
      (exit)))
  (if (tblsearch "BLOCK" insert-name)
    (command-s "_.-INSERT" insert-name "_S" scale-factor
               "_R" (* 180.0 (/ ang pi)) ip)
    (command-s "_.-INSERT" source "_S" scale-factor
               "_R" (* 180.0 (/ ang pi)) ip))
  (setq inserted (entlast))
  (if inserted
    (command-s "_.EXPLODE" inserted ""))
  (setq dynamic-ref (entlast)
        grip-set (and dynamic-ref
                      (ib:calibrate-dynamic-grip
                        dynamic-ref (trans edge-start 1 0) ang
                        assembly-length)))
  (princ
    (strcat "\nInserted "
            size-label
            " dynamic bolt at "
            (rtos d 2 2)
            unit-label
            " diameter with "
            (rtos assembly-length 2 2)
            " drawing-unit head-to-nut grip distance."
            (if grip-set "" " Dynamic Grip property could not be set.")))
  (setvar "CMDECHO" oldecho)
  (princ))

(vl-load-com)
(princ "\nMetric/imperial bolt block builder loaded. Type IBOLT to begin.")
(princ)
