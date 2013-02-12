(defun compare-sets-s (a b)
  (let* ((c 0)
         (l (mapcar (lambda(x)(and (member x a) t)) b))
         (n a)
         m z)
    (setq
     z
     (remove
      nil
      (mapcar
       (lambda(y)
         (prog1
             (if y
                 (nth c b)
               (setq m (cons (nth c b) m))
               nil)
           (setq c (1+ c))))
       l)))
    (mapcar (lambda(x)(setq n (remove x n))) z)
    (list z n m)))

(defun loaddefs-eval (var)
  (let ((b (car var))
        (v (cadr var)))
    (mapcar
     (lambda(x)
       (mapcar
        (lambda(y)
          (eval
           (if (eq (nth 0 y) 'autoload)
           `(autoload
              ,(nth 1 y)
              ,(expand-file-name (nth 2 y) b)
              ,@(nthcdr 3 y))
           y)))
        (nthcdr 2 x)))
     v)))

(defun loaddefs-file-mtime (file)
  (nth 5 (file-attributes file)))

(defun loaddefs-read (ldfs)
  (let (var)
    (with-current-buffer
        (let ((enable-local-variables nil))
          (find-file-noselect ldfs))
      (prog2
          (goto-char (point-min))
          (setq var
                (condition-case err
                    (read (current-buffer))
                  (error
                   nil)))
        (kill-buffer (current-buffer))))))

(defun loaddefs-save (ldfs var)
  (with-temp-file
      (let ((enable-local-variables nil)
            (emacs-lisp-mode-hook nil)
            (find-file-hook nil))
        ldfs)
    (insert (pp-to-string var))
    (message (format "Save %s." ldfs))))

(defun loaddefs-docstr (s a)
  (let* ((a (mapconcat 'symbol-name a " "))
         (a (if (> (length a) 0)(concat " " a) a)))
    (format "\
%s

\(fn%s)" s a)))

(defun loaddefs-gen (lst f)
  `(autoload
     ',(nth 1 lst)
     ,(file-name-sans-extension
       (file-name-nondirectory f))
     ,(loaddefs-docstr
       (if (stringp (nth 3 lst))(nth 3 lst)"Not documented.")
       (nth 2 lst))
     ,(eq 'interactive
          (car (if (stringp (nth 3 lst))(nth 4 lst)(nth 3 lst))))
     ,(plist-get type-lst (nth 0 lst))))

(defun loaddefs-gen-a (lst f)
  `(autoload
     ,(nth 1 lst)
     ,(file-name-sans-extension
       (file-name-nondirectory f))
     ,@(nthcdr 3 lst)))

(defun loaddefs-parse (file dir)
  (let ((f (expand-file-name file dir))
        (type-lst '(defun nil defmacro t))
        var y)
    (with-current-buffer
        (let ((enable-local-variables nil))
          (find-file-noselect f))
      (goto-char (point-min))
      (while (search-forward-regexp ";;;###autoload" nil t)
        (let ((x (read (current-buffer))))
          (setq var (cons
                     (setq
                      y
                      (cond
                       ((memq (car x) type-lst)
                        (loaddefs-gen x f))
                       ((eq (car x) 'autoload)
                        (loaddefs-gen-a x f))
                       (t x)))
                     var))))
      (kill-buffer (current-buffer)))
    (message (format "Parse %s..." f))
    (if y (setq
           var (cons (current-time) (reverse var))
           var (cons file var)))))

(defun loaddefs-update (dir &optional ldfs lf ld var)
  (let* ((v (cadr var))
         (ldfs (or ldfs "_loaddefs"))
         (lf (or lf (expand-file-name ldfs dir)))
         (lfm (or (loaddefs-file-mtime lf) '(0 0 0)))
         (ld (or ld (expand-file-name dir)))
         (dir-changed (if (equal ld (car var)) nil t))
         (ld-files (mapcar (lambda(x)(car x)) v))
         (files (directory-files ld nil "\\.el\\'"))
         (df (compare-sets-s ld-files files))
         (d0 (car df))(d1 (nth 1 df))(d2 (nth 2 df)))
    (if
        (remove
         nil
         (list
          dir-changed
          ;; files don't exist
          (mapcar (lambda(x)(setq v (remove (assoc x v) v))) d1)
          ;; new files
          (mapcar
           (lambda(x)
             (if (time-less-p lfm (loaddefs-file-mtime (expand-file-name x ld)))
                 (setq v (cons (loaddefs-parse x ld) v)))) d2)
          ;; old files
          (remove
           nil
           (mapcar
            (lambda(x)
              (let (changed)
                (if (time-less-p lfm (loaddefs-file-mtime (expand-file-name x ld)))
                    (setq
                     v (remove (assoc x v) v)
                     v (cons (setq changed (loaddefs-parse x ld)) v)))
                changed))
            d0))))
        (prog1
            (setq v (remove nil v)
                  var (list ld v))
          (loaddefs-save lf var))
      var)))

;;;###autoload
(defun lazily (dir &optional ldfs)
  (let* ((st (float-time))
         (ldfs (or ldfs "_loaddefs"))
         (lf (expand-file-name ldfs dir))
         (ld (expand-file-name dir))
         (var (loaddefs-read lf))
         (files (directory-files ld t "\\.el\\'")))
    (setq var (loaddefs-update dir ldfs lf ld var))
    (loaddefs-eval var)
    (- (float-time) st)))

;(test-times 1 (lazily (expand-file-name "_autoload" *init-dir*)))