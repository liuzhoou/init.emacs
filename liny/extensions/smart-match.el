;; * match
(setq liny-match-strategy 'liny-smart-match)

(defvar liny-env-test
  '(("head" (progn (backward-sexp)(skip-chars-backward " \t\n")(bobp)))
    ("tail" (progn (skip-chars-forward " \t\n")(eobp)))
    ("notop" (null (zerop (current-indentation))))
    ("top" (zerop (current-indentation)))))

(defun liny-fetch-env ()
  "liny-fetch-env "
  (let ((test
         (lambda(tst)
           (sort
            (remove
             nil
             (mapcar
              (lambda(x)
                (if (save-excursion (save-restriction (eval (nth 1 x))))
                    (cons (nth 0 x) (or (nth 2 x) 1))))
              tst))
            (lambda(x y)
              (string-lessp (car x)(car y)))))))
        (funcall test liny-env-test)))

(defun liny-fetch-env-mode ()
  "liny-fetch-env-mode is writen by ran9er"
  major-mode)

(defun liny-keywords-match (&optional modes keywords)
  "liny-keywords-match is writen by ran9er"
  (let* ((env (liny-fetch-env))
         (result 0)
         necessary sufficient envl)
    (and
     (catch 'test
       (or (member "all" modes)
           (member (symbol-name (liny-fetch-env-mode)) modes)
           (throw 'test nil))
       (mapc
        (lambda(x)
          (if (equal "+" (substring x 0 1))
              (setq necessary (cons (substring x 1) necessary))
            (setq sufficient (cons x sufficient))))
        keywords)
       (setq envl (mapcar (lambda(x)(car x)) env))
       (while (and
               necessary
               (if (member (car necessary) envl) t
                 (throw 'test nil)))
         (setq necessary (cdr necessary)))
       (mapc
        (lambda(x)
          (if (member (car x) sufficient)
              (setq result (+ (cdr x) result))))
        env))
     result)))

;; * index
(defun liny-alias-push (var alias files)
  (let ((a (assoc alias var)))
    (if (null a)
        (cons (list alias files) var)
      (if (member files (cdr a))
          var
        (let* ((n (cons files (cdr a)))
               (n (cons alias n)))
          (remove a (cons n var)))))))

(defun liny-gen-index-k ()
  (let ((gs (lambda(x)(sort (remove "" (if x (split-string x "[ \t\n]"))) 'string-lessp)))
        alias files)
    (setq
     files
     (mapcar
      (lambda(x)
        (with-temp-buffer
          (insert-file-contents (expand-file-name x liny-repo))
          (mapc (lambda(y)(setq alias (liny-alias-push alias y x)))
                (funcall gs (liny-search-str "alias")))
          (list
           x
           (funcall gs (liny-search-str "modes"))
           (funcall gs (liny-search-str "keywords")))))
      (directory-files liny-repo nil "^[^._].*\\'")))
    (cons alias files)))

(defun liny-snippet-exist-p (snippet)
  (assoc snippet (cdr liny-index)))

(let (print-length print-level selective-display-ellipses)
  (liny-update-index "_keywords_index"
                           (pp-to-string (liny-gen-index-k))))

(defun liny-force-update-keyword ()
  (interactive)
  (let (print-length print-level selective-display-ellipses)
    (liny-update-index
     "_keywords_index"
     (pp-to-string (liny-gen-index-k))
     t)))

;; (insert (concat "\n" (pp-to-string (liny-gen-index-k))))


;; *
(defun liny-smart-match ()
  (let* ((alias (liny-fetch-alias))
         (files (cdr (assoc alias (car liny-index)))))
    (cdar
     (sort
      (mapcar
       (lambda(x)
         (let* ((lst (cdr (assoc x (cdr liny-index))))
                (modes (nth 0 lst))
                (keywords (nth 1 lst))
                (match (liny-keywords-match modes keywords)))
           (if match (cons match x))))
       files)
      (lambda(x y)
        (> (car x)(car y)))))))