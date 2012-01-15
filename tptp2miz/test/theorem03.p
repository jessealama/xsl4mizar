% Distinguished Elements
fof(distinguished_point_d,axiom,point(d)).
fof(distinguished_property_e,axiom,property(e)).

% Defined properties
fof(def_o,axiom,
 (! [X,D] : ((object(X) & point(D)) => (ex1_at(o,X,D) <=>
    (? [D2] : (point(D2) & ex1_at(e,X,D2))))))).

fof(def_a,axiom,
 (! [X,D] : ((object(X) & point(D)) => (ex1_at(a,X,D) <=>
    ~(? [D2] : (point(D2) & ex1_at(e,X,D2))))))).

% The property concept is the property abstract.
fof(being_a_concept_is_being_abstract,axiom,c=a).

% Defined Predication.
fof(def_ex1,definition,
    (! [X,F] : (ex1(F,X) <=> ex1_at(F,X,d)))).

fof(def_enc,axiom,
    (! [X,F] : (enc(X,F) <=> enc_at(X,F,d)))).

% Defined Notions of Equality
fof(def_o_equal_at,axiom,
  (! [X,Y,D] : ((object(X) & object(Y) & point(D)) => (o_equal_at(X,Y,D) <=>
      (ex1_at(o,X,D) & ex1_at(o,Y,D) & (! [D2] : (point(D2) => (! [F] : (property(F) => (ex1_at(F,X,D2) <=> ex1_at(F,Y,D2))))))))))).

fof(def_o_equal,axiom,
    (! [X,Y] : ((object(X) & object(Y)) => (o_equal(X,Y) <=> o_equal_at(X,Y,d))))).

fof(def_a_equal_at,axiom,
  (! [X,Y,D] : ((object(X) & object(Y) & point(D)) => (a_equal_at(X,Y,D) <=>
      (ex1_at(a,X,D) & ex1_at(a,Y,D) & (! [D2] : (point(D2) => (! [F] : (property(F) => (enc_at(X,F,D2) <=> enc_at(Y,F,D2))))))))))).

fof(def_a_equal,axiom,
    (! [X,Y] : ((object(X) & object(Y)) => (a_equal(X,Y) <=> a_equal_at(X,Y,d))))).

fof(def_object_equal_at,axiom,
    (! [X,Y,D] : ((object(X) & object(Y) & point(D)) => (object_equal_at(X,Y,D) <=> (o_equal_at(X,Y,D) | a_equal_at(X,Y,D)))))).

fof(def_object_equal,axiom,
    (! [X,Y] : ((object(X) & object(Y)) => (object_equal(X,Y) <=> object_equal_at(X,Y,d))))).

% Sorting.
fof(sort_ex1_at,axiom,
  (! [F,X,D] : (ex1_at(F,X,D) => (property(F) & object(X) & point(D))))).

fof(sort_enc_at,axiom,
  (! [X,F,D] : (enc_at(X,F,D) => (object(X) & property(F) & point(D))))).

% Theorem: For all concepts X,Y,Z, if X=Y and Y=Z then X=Z.
fof(theorem03,conjecture,
    (! [X,Y,Z] : ((object(X) & object(Y) & object(Z)) =>
      ((ex1_at(c,X,d) & ex1_at(c,Y,d) & ex1_at(c,Z,d)) =>
         ((object_equal_at(X,Y,d) & object_equal_at(Y,Z,d)) => object_equal_at(X,Z,d)))))).
