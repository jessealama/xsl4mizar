
(in-package :cl-user)

(eval-when (:compile-toplevel)
  (ql:quickload "alexandria")
  (ql:quickload "com.gigamonkeys.pathnames"))

(defpackage :ivy-nd
  (:use :cl :alexandria :com.gigamonkeys.pathnames))

(in-package :ivy-nd)

(defun first-n (lst n)
  (loop
     for i from 1 upto n
     for elt in lst
     collecting elt into items
     finally (return items)))

(defun downcase (string)
  (format nil "~(~a~)" string))

(defun upcase (string)
  (format nil "~@(~a~)" string))

(defgeneric render-formula (formula stream)
  (:documentation "Emit a TPTP XML representation of FORMULA to STREAM."))

(defmethod render-formula ((formula symbol) stream)
  (cond ((string= (symbol-name formula) "FALSE")
	 (format stream "<defined-predicate name=\"false\"/>")
	 (terpri stream))
	(t
	 (error "We don't know how to render the formula-symbol '~a'~%" formula))))

(defmethod render-formula ((formula null) stream)
  (declare (ignore stream))
  (error "We don't know how to render the empty list as a formula!"))

(defun render-disjunction (left-disjunct right-disjunct stream)
  (format stream "<disjunction>")
  (terpri stream)
  (render-formula left-disjunct stream)
  (render-formula right-disjunct stream)
  (format stream "</disjunction>")
  (terpri stream)
  t)

(defun render-negation (unnegated stream)
  (format stream "<negation>")
  (terpri stream)
  (render-formula unnegated stream)
  (format stream "</negation>")
  (terpri stream)
  t)

(defgeneric render-term (term stream))

(defmethod render-term ((term symbol) stream)
  (let ((name (symbol-name term)))
    (cond ((string= name "") (error "We cannot render the empty string as a term!~%"))
	  ((char= (char name 0) #\V)
	   (format stream "<variable name=\"~a\"/>" (upcase name))
	   (terpri stream))
	  (t
	   (error "Don't know how to render the term '~a'~%" term)))))

(defmethod render-term ((term null) stream)
  (declare (ignore stream))
  (error "We don't know how to render the empty list as a term!~%"))

(defmethod render-term ((term list) stream)
  (let ((operator (first term))
	(arguments (rest term)))
    (cond (arguments
	   (format stream "<function name=\"~a\">" (downcase operator))
	   (terpri stream)
	   (dolist (argument arguments)
	     (render-term argument stream))
	   (format stream "</function>"))
	  (t
	   (format stream "<function name=\"~a\"/>" (downcase operator))))
    (terpri stream)
    t))

(defun render-predication (predicate argument-list stream)
  (format stream "<predicate name=\"~a\">" (downcase predicate))
  (terpri stream)
  (dolist (argument argument-list)
    (render-term argument stream))
  (format stream "</predicate>")
  (terpri stream)
  t)

(defmethod render-formula ((formula list) stream)
  ;; the list is non empty because we another method on
  ;; RENDER-FORMULA handles the null case
  (let ((operator (first formula)))
    (cond ((string= (downcase operator) "or")
	   (render-disjunction (second formula) (third formula) stream))
	  ((string= (downcase operator) "not")
	   (render-negation (second formula) stream))
	  (t
	   (render-predication operator (cdr formula) stream)))))

(defun render-step (step stream steps)
  (destructuring-bind (label (rule-name . rule-data) formula junk)
      step
    (declare (ignore junk)) ;; JUNK seems to always be NIL
    (format stream "<Derivation name=\"~a\">" (downcase label))
    (terpri stream)
    (let ((dependent-steps (remove-if-not #'(lambda (thing)
					      (when thing
						(or (symbolp thing)
						    (integerp thing))))
					  rule-data)))
      (render-formula formula stream) ;; should end with a newline
      (if dependent-steps
	  (if (string= (downcase rule-name) "instantiate")
	      (loop
		 with substitution = (second rule-data)
		 initially
		   (format stream "<Rule name=\"~a\">" (downcase rule-name))
		   (terpri stream)
		 for (variable . term) in substitution
		 do
		   (format stream "<Substitution>")
		   (terpri stream)
		   (render-term variable stream)
		   (render-term term stream)
		   (format stream "</Substitution>")
		   (terpri stream)
		 finally
		   (format stream "</Rule>")
		   (terpri stream))
	      (format stream "<Rule name=\"~a\"/>" (downcase rule-name)))
	  (format stream "<Rule name=\"axiom\"/>"))
      (terpri stream)
      (dolist (earlier-step-label dependent-steps)
	(let ((earlier-step (find earlier-step-label steps
				  :key #'first
				  :test #'(lambda (key-1 key-2)
					    (string= (downcase key-1)
						     (downcase key-2))))))
	  (if earlier-step
	      (render-step earlier-step stream steps)
	      (error "We could not find a step with the label ~a in the IVY proof~%~{~a~%~}~%" earlier-step steps))))))
  (format stream "</Derivation>")
  (terpri stream))

(defgeneric ivy-nd (ivy-input)
  (:documentation "Construct a natural deduction proof from the IVY source IVY-INPUT."))

(defmethod ivy-nd ((ivy-list list))
  (with-output-to-string (s)
    (format s "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>")
    (terpri s)
    (render-step (car (last ivy-list)) s ivy-list)))

(defmethod ivy-nd :around ((ivy-file pathname))
  (if (file-exists-p ivy-file)
      (call-next-method)
      (error "There is no IVY file at~%~%  ~a~%" (namestring ivy-file))))

(defmethod ivy-nd ((ivy-file pathname))
  (let (initial-proof-object)
    (handler-case
	(setf initial-proof-object
	      (with-open-file (ivy ivy-file
				   :direction :input
				   :if-does-not-exist :error)
		(read ivy nil nil)))
      (error (err) (error "Something went wrong constructing a natural deduction derivation from the IVY file at~%~%  ~a~%~%The error was:~%~%  ~a" ivy-file err)))
    (when initial-proof-object
      (ivy-nd initial-proof-object))))

(defun serialize-ivy-to-file (ivy-input output-path)
  "Compute the XML serialization of IVY-INPUT, saving the result to OUTPUT-PATH."
  (with-open-file (output-xml output-path
			      :direction :output
			      :if-does-not-exist :create
			      :if-exists :supersede)
    (format output-xml (ivy-nd ivy-input)))
  t)

