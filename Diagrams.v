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

Definition decide {A} R (a a':A) := {R a a'} + {R a a' -> False}.

Lemma bindIn {A B} {b:B} {l:list A} {f:A->list B} x : In x l -> In b (f x) -> In b (x <- l;; f x).
  cbn.
  intros.
  apply (concatIn (f x)); intuition.
  apply in_map.
  intuition.
Qed.

Global Instance eqDecIndex {A} {l:list A} : eqDec (index l).
  constructor.
  intros i i'.
  induction l; [inversion i|].
  refine(match i as ir in index lr
  return a::l = lr -> forall i':index lr, decide _ ir i'
  with
  | found => _
  | next im => _
  end eq_refl i'). 
  - clear IHl i i'.
    intros _.
    clear a l.
    intros i'.
    rename a0 into a.
    rename l0 into l.
    refine(match i' as ir' in index lr
    return match lr as lr return index lr -> Type with
           | [] => fun _ => False
           | am :: lm => fun i' : index (am :: lm) => decide eq found i'
           end ir'
    with
    | found => _
    | next _ => _
    end).
    + compute.
      left.
      reflexivity.
    + compute.
      right.
      intro h; inversion h.
  - clear i'.
    intros e i'.
    inversion e; clear e.
    subst.
    rename a0 into a.
    rename l0 into l.
    clear i.
    refine(match i' as ir' in index lr
    return a::l = lr -> match lr as lr return index lr -> Type with
                       | [] => fun _ => False
                       | am :: lm => fun i' : index (am :: lm) => forall im, decide eq (next im) i'
                       end ir'
    with
    | found => _
    | next im' => _
    end eq_refl im).
    + compute.
      intros.
      right.
      intro h; inversion h.
    + clear im.
      intros e im.
      inversion e; clear e.
      subst.
      destruct (IHl im im').
      * subst.
        left.
        reflexivity.
      * compute in *.
        right.
        intro e; inversion e.
        crush.
Defined. 

Global Instance enumerableIndex {A} {l:list A}: enumerable (index l) := {| 
  enumerate := (fix rec l := match l return list (index l) with 
    | [] => []
    | a::l' => found :: @next _ _ _ <$> rec l'
    end) l
|}.
Proof.
  intros i.
  induction i.
  - cbn.
    left.
    reflexivity.
  - cbn.
    right.
    apply in_map.
    intuition.
Defined.

Global Instance monadOption : Monad option := {|
  ret A a := Some a;
  bind A B v f := match v with None => None | Some a => f a end
|}.
Proof.
  - intros; reflexivity.
  - intros ? []; reflexivity.
  - intros ? ? ? [] ? ?; reflexivity.
Defined.    

Module PartialMap.
Section PartialMap.
  Variable A : Type.
  
  Definition PartialMap (B:A->Type) := forall a, option (B a).

  Context `{enumerable A}.

  Definition isSome {T} (v:option T) :=
    match v with Some _ => true | None => false end.

  Definition size {B} (m:PartialMap B) : nat.
    refine ((fix rec l := match l with 
    | [] => 0
    | a::l' => match m a with 
                | None => 0 
                | Some _ => 1 
                end + rec l'
    end) enumerate).
  Defined.

  Lemma emptySize {B} : @size B (fun _ => None) = 0.
    unfold size.
    induction enumerate.
    - reflexivity.
    - cbn in *.
      rewrite IHl.
      reflexivity.
  Qed.

  Lemma maxSize {B m} : @size B m <= length enumerate.
  Admitted.

  Lemma fullSize {B m} : @size B m = length enumerate -> forall a, m a <> None.
    intros h a.
  Admitted.

  Definition map {B C} (m:PartialMap B) (f:forall a, B a -> C a) : PartialMap C :=
    fun a => option_map (f a) (m a).

  Lemma mapSize {B C m f} : @size B m = @size C (map m f).
    unfold map.
    unfold size.
    induction enumerate.
    - reflexivity.
    - cbn in *.
      rewrite IHl; clear IHl.
      f_equal.
      destruct (m a); reflexivity.
  Qed.

  Lemma mapNone {B C m k} {f:forall a, B a -> C a} : m k = None -> map m f k = None.
    intro.
    unfold map.
    unfold option_map.
    break_match; congruence.
  Qed.

  Context `{eqDec A}.

  Definition update {B} (m:PartialMap B) a (b:B a) : PartialMap B.
    refine (fun a' => if a =? a' then _ else m a').
    subst.
    exact (Some b).
  Defined.

  Lemma updateSize {B m a b} : m a = None -> size (@update B m a b) = S (size m).
    intro h.
    unfold size.
  Admitted.
End PartialMap.
End PartialMap.

Module Graph.
Section Graph.

Class Graph := {
  Vertex : Type;
  Edge : Vertex -> Vertex -> Type
}.

Context `{Graph}.

Inductive star {A} {R:A->A->Type} : A -> A -> Type :=
| refl {a} : star a a
| step  {a b c} : R a b -> star b c -> star a c.

Inductive star' {A} {R:A->A->Type} : A -> A -> Type :=
| refl' {a} : star' a a
| step'  {a b c} : star' a b -> R b c -> star' a c.

Definition Path := @star Vertex Edge.
Definition Path' := @star' Vertex Edge.

Context `{eqDec Vertex}.
Context `{enumerable Vertex}.
Context `{forall v v', enumerable (Edge v v')}.

Definition vertices := @enumerate Vertex _.
Definition edges v v' := @enumerate (Edge v v') _.

Definition nonTrivialPath s d := {d':Vertex & Path' s d' * Edge d' d} % type.

Definition cycle s := nonTrivialPath s s.

Definition Cycle := {s:Vertex & cycle s}.

Fixpoint length {s d} (p:Path s d) : nat :=
  match p with
  | refl => 0
  | step _ p' => S (length p')
  end.

Import PartialMap.
Arguments PartialMap [_] _.
Arguments size [_ _ _] _.
Arguments map [_ _ _] _ _ _.
Arguments update [_ _ _] _ _ _ _.

Require Import Omega.

Definition longPathCycle {s d} (p:Path s d) : length p >= List.length vertices -> Cycle.
  intro h.
  refine ((fun (m:PartialMap (fun x => nonTrivialPath x s)) (_:size m = 0) => _) (fun _ => None) _); [|shelve].
  assert (length p + size m >= List.length vertices) by omega.
  clear h e.
  induction p as [v|v v' d e p' rec].
  - cbn in *.
    refine (match m v as o return m v = o -> Cycle with
    | Some ntp => fun _ => [v & ntp : cycle v]
    | None => _
    end eq_refl).
    shelve.
  - refine (match m v as o return m v = o -> Cycle with
    | Some ntp => fun _ => [v & ntp : cycle v]
    | None => fun _ => _
    end eq_refl).
    refine (let m' : PartialMap (fun x => nonTrivialPath x v') := map m _ in _). {
      intros x [y [pxy exv]].
      refine [v & (step' pxy exv, e)].
    }
    refine (let m'' := update m' v [v & (refl', e)] in _).
    refine (rec m'' _).
    shelve.
Proof. Unshelve.
  + clear.
    apply emptySize.
  + intro h.
    exfalso.
    clear -H3 h.
    unfold ge in H3.
    inversion H3.
    * specialize (@fullSize _ _ _ m); intro.
      unfold vertices in *.
      symmetry in H2.
      specialize (H0 H2 v).
      congruence.
    * specialize (@maxSize _ _ _ m); intro.
      unfold vertices in *.
      omega.
  + clear rec.
    cbn in *.
    enough (S (size m) = size m'') by omega.
    symmetry.
    subst m''.
    subst m'.
    match goal with
    | |- context[map m ?f] => generalize f; intros g
    end.
    rewrite (@mapSize _ _ _ _ _ g).
    apply updateSize.
    refine (@mapNone _ _ _ _ _ g e0).
Defined.

Definition Acyclic : option (forall s, cycle s -> False).
 



Definition isCyclic : {s:Vertex & cycle s} + {forall s, cycle s -> False}.












Find cycles in a dac




Fixpoint reverse {A} (l:list (option A)) : option (list A) :=
  match l with 
  | [] => Some []
  | a::l' => a <- a;;
             l' <- reverse l';;
             ret (a::l')
  end.

Definition enumerablePaths s : option (enumerable {d : Vertex & Path s d}).
  refine ((fix rec fuel := match fuel
  return forall v, option (enumerable {d : Vertex & Path v d}) with
  | 0 => fun _ => None
  | S fuel => fun v => _
  end) (length vertices) s).
  clear s.
  refine (let ps := d <- vertices;; 
                    e <- edges v d;;
                    _ in _).
  shelve.
  refine (match rec fuel d with
  | None => ret None
  | Some ps => p <- @enumerate _ ps;;
               ret (Some [projT1 p & step e (projT2 p)])
  end).
  destruct (reverse ps) as [ps'|] eqn:h; [|exact None].
  refine (Some {| enumerate := [v & refl] :: ps' |}).
Proof.
  apply ADMIT.
Defined.

End Graph.
End Graph.
Import Graph.

Import Category.

Module Diagram.
Section Diagram.

Class Diagram `{Category} := {
  Vertex : Type;
  vertexObject : Vertex -> object;
  Arrow : Vertex -> Vertex -> Type;
  arrowMorphism {a b} : Arrow a b -> (vertexObject a) → (vertexObject b)
}.

Context `{Diagram}.

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

End Diagram.
End Diagram.
Import Diagram.

Section ProductDiagram.

Context `{Category}.

Variable prod : object -> object -> object.
Variable factorizer : forall {a b c:object} (p:c → a) (q:c → b), c → prod a b.
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
  [ci & [prodi & factorizer a b c p q]];
  [prodi & [ai & fst a b]];
  [prodi & [bi & snd a b]]
].

Definition arrowsSection (s d:Vertex) : list (lookup s → lookup d).
  refine(
  (fix rec l :=
    match l with
    | [] => []
    | i :: l' => _
    end) arrows).
  destruct i as [s' [d' f]].
  specialize (rec l').
  refine (
  match (s, d) =? (s', d') with
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

Existing Instance diagramGraph.

Goal True.
  refine (let v:list Vertex := enumerate in _).
  refine (let e:list (Edge ci prodi) := enumerate in _).
  vm_compute in v.
  vm_compute in e.

  refine (let e := enumerablePaths ci in _).

  Check enumerablePaths.

  vm_compute in e.




Lemma prodCommutative : commutative.
  unfold commutative.
  cbn.


  intros s d P Q. 
  

enumerablePaths 
  

  inversion s; subst.
  inversion s.
  inversion l.
  inversion s.
  inversion s.
  inversion s.


Instance prodDiagram : Diagram := {|
  Diagram.Vertex := Vertex;
  vertexObject := lookup;
  Arrow s d := index (arrowsFun s d);
  arrowMorphism x y := lookup
|}.






(*
Instance enumerableIndex {A} {l:list A} : enumerable (index l) := {| 
  enumerate:= _
|}.
Proof.
  - dependent induction l.
    + exact [].
    + refine (found :: map _ IHl).
      apply next.
  - intros x.
    induction l.
    + inversion x.
    + cbn in *.
      apply ADMIT.
Defined.



















Definition objects := [a; b; c; prod a b].
Definition Vertex := {o:object & elem o objects}.


Hint Constructors elem.
Definition elemA : Vertex := [a & head].
Definition elemB : Vertex := [b & tail head].
Definition elemC : Vertex := [c & tail (tail head)].
Definition elemProd : Vertex := [prod a b & tail (tail (tail head))].

(*
Definition Arrow : Vertex -> Vertex -> Type.
  intros [s si] [d di].
  refine(match si, di with
  | tail (tail head), head => unit
  | _,_ => Empty_set
  end).
Defined.
*)

Definition arrows (s d:Vertex) : list (projT1 s → projT1 d).
  destruct s as [s si].
  destruct d as [d di].
  cbn.
  refine(match si in elem _ l return l = objects -> list (s → d) with
  | head => _
  | tail _ => _
  end eq_refl).
  - intros.
    inversion H0.
    subst.
    admit.
  - 


  inversion si.
  - exact [].
  - exact [].
Defined.

Print arrows.

  - 


  inversion si.
  inversion di.


Admitted.

Definition Arrow s d := {m:projT1 s → projT1 d & elem m (arrows s d)}.

(*
Definition arrows : list {s:Vertex & {d:Vertex & projT1 s → projT1 d}} := [
  [elemC & [elemA & p]];
  [elemC & [elemB & q]];
  [elemC & [elemProd & factorizer a b c p q]];
  [elemProd & [elemA & fst a b]];
  [elemProd & [elemB & snd a b]]
].
*)

Instance prodDiagram : Diagram := {|
  Diagram.Vertex := Vertex;
  vertexObject := $(apply projT1)$;
  Diagram.Arrow := Arrow;
  arrowMorphism x y := $(apply projT1)$
|}.





  induction arrows.
 
 + exact nil.
  


  - intros [s si] [d di].
    

Definition arrows : list {s:object & {d:object & s → d}} := [
  [c & [a & p]]
].







(* Definition arrows (s d:Vertex) : list (projT1 s → projT1 d).
  destruct s as [s si].
  destruct d as [d di].
  cbn in *.
  refine (
  match si in elem _ l' return list (s → d) with
  | head => [_]
  | _ => []
  end).


  match si, di with
  | tail (tail head), head => [_]
  | _, _ => []
  end).
  


fun v v' :=
  match v,v' with
  | 
  | 
  | 
*)









  fstOk {a b c} {p:c → a} {q:c → b} : factorizer p q ∘ fst = p;
  sndOk {a b c} {p:c → a} {q:c → b} : factorizer p q ∘ snd = q;
  pairUnique {a b c} {p:c → a} {q:c → b} f : 
    f p q ∘ fst = p -> f p q ∘ snd = q -> f p q = factorizer p q






Instance prodIsProduct : @Product Coq := {|
  prod := Datatypes.prod : @object Coq -> @object Coq -> @object Coq;
  factorizer a b c p q x := (p x, q x);
  fst := @Datatypes.fst;
  snd := @Datatypes.snd
|}.
Proof.  




Notation "A → B" := (morphism A B) (at level 45).
Notation "f ∘ g" := (composition f g).




In s vertices -> In d vertices -> Path s d
    



(*
  vertices : list object;
  arrows : forall (a:{a | In a vertices}) (b:{b | In b vertices}), list (proj1_sig a → proj1_sig b) *)

{v | In v vertices} (fun a b => {a | In a (arrows a b)}).




Definition Arrow := morphism

Class Vertex := {|
  T : Type;
  value : T
|}.









Variable A B C : Category.

Check IdentityFunctor.

Set Printing All.

Instance FirstFunctor (A B C:Category) : Functor (CatProduct A B) C := {|
  fobj a := ();
  fmap a b f:= _
|}.
Proof.
  - intros. 
    reflexivity.
  - intros. 
    rewrite Category.rightId.
    reflexivity.
Defined.



Variable F : BiFunctor A (IdentityFunctor@id Coq) C.

Variable F : Functor (CatProduct A A) C.
Variable F : Functor (CatProduct B B) C.


