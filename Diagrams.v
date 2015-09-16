Require FunctionalExtensionality.
Require ProofIrrelevance.
Require Import Program.
Require Import List.
Require Import Equality.
Import EqNotations.
Require Import Arith.
Require Import Misc.
Require Import JamesTactics.
Require Import Enumerable.
Require Import Monad.
Require Import CategoryTheory.
Require Import ListEx.
Require Import EqDec.
Require Import CpdtTactics.
Import ListNotations.
Import Category.

Definition groupBy {A C} `{eqDec A} `{enumerable A} {B:A->Type} (l:list (sigT B)) (f:forall a:A, list (B a) -> C) : list C.
  refine (a <- enumerate;; _).
  refine (ret (f a _)).
  refine (e <- l;; _).
  destruct e as [a' b].
  refine (if a =? a' then ret _ else []).
  subst.
  exact b.
Defined.

Definition nonsymmetricNonreflexiveCrossproduct {A} (l:list A) : list (A * A).
  refine ((fix rec l :=
    match l with
    | [] => []
    | a::l' => _ ++ rec l'
    end) l).
  refine ((fix rec' l :=
    match l with
    | [] => []
    | a'::l' => (a,a') :: rec' l'
    end) l').
Defined.

Module Graph.
Section Graph.

Class Graph := {
  Vertex : Type;
  Edge : Vertex -> Vertex -> Type
}.

Context `{Graph}.

Inductive Path : Vertex -> Vertex -> Type :=
| refl {a} : Path a a
| step  {a b c} : Edge a b -> Path b c -> Path a c.

Inductive Path' : Vertex -> Vertex -> Type :=
| refl' {a} : Path' a a
| step'  {a b c} : Edge a b -> Path' b c -> Path' a c.

Context `{eqDec Vertex}.
Context `{enumerable Vertex}.
Context `{forall v v', enumerable (Edge v v')}.

Definition vertices := @enumerate Vertex _.
Definition edges v v' := @enumerate (Edge v v') _.

End Graph.
End Graph.
Import Graph.

Module Diagram.
Section Diagram.

Class Diagram `{Category} := {
  Vertex : Type;
  vertexObject : Vertex -> object;
  Arrow : Vertex -> Vertex -> Type;
  arrowMorphism {a b} : Arrow a b -> (vertexObject a) → (vertexObject b)
}.

Context `{Diagram}.
Context `{eqDec Vertex}.
Context `{enumerable Vertex}.
Context `{forall v v', enumerable (Arrow v v')}.

Instance diagramGraph : Graph := {| 
  Graph.Vertex := Vertex;
  Graph.Edge := Arrow
|}.

Fixpoint composePath {s d} (p:Path s d) : vertexObject s → vertexObject d :=
  match p with
  | refl => id
  | step a p' => arrowMorphism a ∘ composePath p'
  end.

Definition commutative := forall s d (p q:Path s d), composePath p = composePath q.

Existing Instance diagramGraph.

Definition listPaths s : list {d : Vertex & Path s d}.
  refine ((fix rec fuel := match fuel
  return forall v, list {d : Vertex & Path v d} with
  | 0 => fun _ => []
  | S fuel => fun v => _
  end) (List.length vertices) s).
  clear s.
  refine ([v & refl]::_).
  refine (d <- vertices;; _).
  refine (e <- edges v d;; _).
  refine (P <- rec fuel d;; _).
  refine (ret [projT1 P & step e (projT2 P)]).
Defined.

Definition denoteDiagram : Prop.
  refine ((fix rec (l:list Prop) := match l with
    | [] => True
    | [h] => h
    | h::l' => h /\ rec l'
    end) _).
  refine (v <- @enumerate Vertex _;; _).
  refine (concat (groupBy (listPaths v) (fun v' ps => _))).
  refine (_ <$> nonsymmetricNonreflexiveCrossproduct ps).
  intros [P Q].
  refine (composePath P = composePath Q).
Defined.

Lemma denoteDiagramOk : denoteDiagram <-> forall s d (P Q:Path s d), composePath P = composePath Q.
Admitted.

End Diagram.
End Diagram.

Import Diagram.

Module Product.
Section ProductDiagram.

Context `{Category}.

Variable prod : object -> object -> object.
Variable pair : forall {a b c:object} (p:c → a) (q:c → b), c → prod a b.
Variable fst : forall {a b:object}, prod a b → a.
Variable snd : forall {a b:object}, prod a b → b.

Variable a b c:object.
Variable p:c → a.
Variable q:c → b.

Notation "[ a & b ]" := (existT _ a b).

Definition objects := [a; b; c; prod a b].
Definition Vertex := index objects.

Definition ai : Vertex := found.
Definition bi : Vertex := next found.
Definition ci : Vertex := next (next found).
Definition prodi : Vertex := next (next (next found)).

Definition arrows : list {s:Vertex & {d:Vertex & lookup s → lookup d}} := [
  [ci & [ai & p]];
  [ci & [bi & q]];
  [ci & [prodi & pair a b c p q]];
  [prodi & [ai & fst a b]];
  [prodi & [bi & snd a b]]
].

Definition arrowsSection (s d:Vertex) : list (lookup s → lookup d).
  refine((fix rec l :=
    match l with
    | [] => []
    | i :: l' => _
    end) arrows).
  destruct i as [s' [d' f]].
  specialize (rec l').
  refine (match (s, d) =? (s', d') with
  | left e => _ :: rec 
  | right _ => rec end
  ).
  inversion e.
  subst.
  exact f.
Defined.

Instance prodDiagram : Diagram := {|
  Diagram.Vertex := Vertex;
  vertexObject := lookup;
  Arrow s d := index (arrowsSection s d);
  arrowMorphism x y := lookup
|}.

Definition productOk := denoteDiagram.

End ProductDiagram.

About productOk.

Class Product `{Category} := {
  prod : object -> object -> object;
  pair {a b c:object} (p:c → a) (q:c → b) : c → prod a b;
  fst {a b:object} : prod a b → a;
  snd {a b:object} : prod a b → b;
  productOk {a b c} {p:c → a} {q:c → b} : productOk prod a b c
(*  pairUnique {a b c} {p:c → a} {q:c → b} f : 
    f p q ∘ fst = p -> f p q ∘ snd = q -> f p q = factorizer p q *)
}.
Opaque morphism.
Opaque object.
Opaque composition.
Opaque id.

End ProductDiagram.



End Product.
Import Product.

Instance prodIsProduct : @Product Coq := {|
  prod := Datatypes.prod : @object Coq -> @object Coq -> @object Coq;
  factorizer a b c p q x := (p x, q x);
  fst := @Datatypes.fst;
  snd := @Datatypes.snd
|}.
Proof.  
  - compute.
    intros.
    extensionality x.
    reflexivity.
  - compute.
    intros.
    extensionality x.
    reflexivity.
  - compute.
    intros ? ? ? ? ? f h h'.
    extensionality x.
    specialize (equal_f h x); clear h; intro h.
    specialize (equal_f h' x); clear h'; intro h'.
    rewrite <- h.
    rewrite <- h'.
    destruct (f p q x).
    reflexivity.
Defined.

Definition Sum {C:Category} := @Product (co C).

Definition sumIsSum : @Sum Coq.
  unfold Sum.
  refine {|
    prod := sum : @object (co Coq) -> @object (co Coq) -> @object (co Coq);
    factorizer a b c p q x := match x with inl a => p a | inr b => q b end;
    fst := @inl;
    snd := @inr
  |}.
  - compute. 
    intros.
    extensionality x.
    reflexivity.
  - compute. 
    intros.
    extensionality x.
    reflexivity.
  - compute.
    intros ? ? ? ? ? f h h'.
    extensionality x.
    destruct x as [l | r].
    + specialize (equal_f h l); clear h; intro h.
      rewrite <- h.
      reflexivity.
    + specialize (equal_f h' r); clear h; intro h.
      rewrite <- h.
      reflexivity.
Defined.


















Instance prodIsProduct : @Product Coq := {|
  prod := Datatypes.prod : @object Coq -> @object Coq -> @object Coq;
  factorizer a b c p q x := (p x, q x);
  fst := @Datatypes.fst;
  snd := @Datatypes.snd
|}.
Proof.  


(*
  fstOk {a b c} {p:c → a} {q:c → b} : factorizer p q ∘ fst = p;
  sndOk {a b c} {p:c → a} {q:c → b} : factorizer p q ∘ snd = q;
  pairUnique {a b c} {p:c → a} {q:c → b} f : 
    f p q ∘ fst = p -> f p q ∘ snd = q -> f p q = factorizer p q
*)

Instance prodIsProduct : @Product Coq := {|
  prod := Datatypes.prod : @object Coq -> @object Coq -> @object Coq;
  factorizer a b c p q x := (p x, q x);
  fst := @Datatypes.fst;
  snd := @Datatypes.snd
|}.
Proof.  
