;;; Adds the dynamic-bolt launcher to the WELDSYM toolbar.
;;; Kept separate so updates to weldsym_safe.lsp cannot remove the button.

(vl-load-com)

(defun c:BOLTTOOL (/ bolt-file)
  (setq bolt-file (findfile "ImperialBoltBlock.lsp"))
  (if (findfile bolt-file)
    (progn
      (load bolt-file)
      (c:IBOLT))
    (alert "The dynamic-bolt program was not found in the AutoCAD Support folder."))
  (princ))

(defun ibolt:ensure-toolbar-button (/ group toolbars tb index)
  (if (and weldsym:get-menugroup
           weldsym:get-toolbar
           weldsym:add-toolbar-button)
    (progn
      (setq group (weldsym:get-menugroup "ACAD"))
      (if group
        (progn
          (setq toolbars (vla-get-Toolbars group)
                tb (weldsym:get-toolbar toolbars "WELDSYM"))
          (if (null tb)
            (progn
              (if weldsym:ensure-toolbar
                (weldsym:ensure-toolbar))
              (setq tb (weldsym:get-toolbar toolbars "WELDSYM"))))
          (if tb
            (progn
              (setq index (vla-get-Count tb))
              (weldsym:add-toolbar-button
                tb index "Bolt" "Insert dynamic bolt and nut assembly"
                "BOLTTOOL " "ibolt16.bmp" "ibolt32.bmp")
              (vla-put-Visible tb :vlax-true)
              T)))))))

(defun c:BOLTTOOLBAR ()
  (if (ibolt:ensure-toolbar-button)
    (princ "\nDynamic-bolt button added to the WELDSYM toolbar.")
    (princ "\nCould not find or create the WELDSYM toolbar."))
  (princ))

(vl-catch-all-apply 'ibolt:ensure-toolbar-button '())
(princ "\nDynamic-bolt toolbar integration loaded.")
(princ)
