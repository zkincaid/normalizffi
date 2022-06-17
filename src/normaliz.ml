open Ctypes

let debug = ref false

let ( let* ) o f =
  match o with
  | Ok x -> f x
  | Error e -> Error e

let set_debug flag =
  debug := flag;
  let f = C.Functions.Normaliz.debug_normaliz in
  if flag then f 1 else f 0

type 'a cone = {
  rays: 'a list list;
  subspace: 'a list list;
  inequalities: 'a list list; (* a1 x1 *)
  lattice_equations: 'a list list;
  excluded_face_inequalities: 'a list list; (* a1 x1 + ... + an xn > 0 *)
  ambient_dim: int
}

let empty_cone = {rays = [];
                  subspace = [];
                  inequalities = [];
                  lattice_equations = [];
                  excluded_face_inequalities = [];
                  ambient_dim = 0
                 }

let add_vector vectors vector: ('a list list * int, string) result =
  if vectors = [] then Result.ok ([vector], List.length vector)
  else
    let ambient_dim = List.length (List.hd vectors) in
    let dim = List.length vector in
    if ambient_dim = dim then
      Result.ok ((vector :: vectors), dim)
    else
      let error_str =
        Format.sprintf "Trying to add vector of length %d to vectors of length %d"
          dim ambient_dim in
      Result.error error_str

let add_vector_to_cone get set cone vec =
  let* (matrix, dim) = add_vector (get cone) vec in
  if cone.ambient_dim = 0 || cone.ambient_dim = dim then
    Result.ok { (set cone matrix) with ambient_dim = dim}
  else
    let error_str =
      Format.sprintf "Trying to add vector of length %d to cone with ambient dimension %d"
        dim cone.ambient_dim in
    Result.error error_str

(* Partial application yields weak monomorphic types *)
let add_ray cone vec =
  add_vector_to_cone
    (fun cone -> cone.rays)
    (fun cone matrix -> { cone with rays = matrix })
    cone vec

let add_subspace_generator cone vec =
  add_vector_to_cone
    (fun cone -> cone.subspace)
    (fun cone matrix -> { cone with subspace = matrix })
    cone vec

let add_inequality cone vec =
  add_vector_to_cone
    (fun cone -> cone.inequalities)
    (fun cone matrix -> { cone with inequalities = matrix })
    cone vec

let add_lattice_equation cone vec =
  add_vector_to_cone
    (fun cone -> cone.lattice_equations)
    (fun cone matrix -> { cone with lattice_equations = matrix })
    cone vec

let add_excluded_face cone vec =
  add_vector_to_cone
    (fun cone -> cone.excluded_face_inequalities)
    (fun cone matrix -> { cone with excluded_face_inequalities = matrix })
    cone vec

let add_vectors_to_cone add cone vecs  =
  List.fold_right
    (fun vec cone_opt ->
       let* cone' = cone_opt in
       add cone' vec)
    vecs (Result.ok cone)

let add_rays cone vecs = add_vectors_to_cone add_ray cone vecs
let add_subspace_generators cone vecs = add_vectors_to_cone add_subspace_generator cone vecs
let add_inequalities cone vecs = add_vectors_to_cone add_inequality cone vecs
let add_lattice_equations cone vecs = add_vectors_to_cone add_lattice_equation cone vecs
let add_excluded_face_inequalities cone vecs = add_vectors_to_cone add_excluded_face cone vecs

(* Treat cone as opaque *)

type homogeneous = Homogeneous 
type inhomogeneous = Inhomogeneous

let () =
  (* Phantom constructors for phantom types *)
  ignore (Homogeneous); ignore (Inhomogeneous)

type 'a cone_ptr = Ptr of C.Types.cptr

(* To load Normaliz in *)
external dummy_new_cone: unit -> unit = "new_cone"

(*
let dimensions (l : 'a list list) : int * int =
  let m = List.length l in
  if m > 0 then (m, List.length (List.hd l))
  else (0, 0)
*)

let rec zeros n : FfiLib.zz list =
  assert (n >= 0);
  if n = 0 then []
  else Mpzf.of_int 0 :: zeros (n - 1)

(*
let minus_one n : zz list =
  assert (n > 0);
  Mpzf.of_int (-1) :: zeros (n - 1)
*)

let one n pos : FfiLib.zz list =
  assert (n > 0);
  List.concat [zeros pos; [Mpzf.of_int 1]; zeros (n - pos - 1)]

let identity_matrix n : FfiLib.zz list list =
  assert (n > 0);
  let rec dec n =
    if n = 0 then [0]
    else n :: dec (n - 1) in
  List.map (one n) (dec (n - 1))

let negate_vectors ll =
  List.map (fun l -> List.map (fun x -> Mpzf.neg x) l) ll

let add_equalities cone vecs =
  add_inequalities cone (List.concat [vecs; negate_vectors vecs])

let new_cone cone : homogeneous cone_ptr =
  let dim = cone.ambient_dim in
  let num_rays = List.length cone.rays in
  let num_subspace_gens = List.length cone.subspace in
  let num_eqns = List.length cone.lattice_equations in
  let num_excluded_faces = List.length cone.excluded_face_inequalities in
  (* We always augment the cone with 1 >= 0 to prevent problems with
     dehomogenizing, which typically arises when the dehomogenizing component
     is possibly negative. *)
  let (inequalities, num_ineqs) =
    (one dim 0 :: cone.inequalities, List.length cone.inequalities + 1) in
  if dim = 0 then invalid_arg "normalizffi: normaliz: new_cone: ambient dimension is 0"
  else
    let alloc_array l =
      if l = [] then
        from_voidp C.Types.integer null
      else
        let open FfiLib in
        List.concat l
        |> integer_array_of_zz_list
        |> integer_array_start
        |> from_voidp C.Types.integer
    in    
    let rays_ptr = alloc_array cone.rays in
    let subspace_gens_ptr = alloc_array cone.subspace in
    let inequalities_ptr = alloc_array inequalities in
    let lattice_equations_ptr = alloc_array cone.lattice_equations in
    let excluded_face_inequalities_ptr =
      alloc_array cone.excluded_face_inequalities      
    in
    let open FfiLib in
    let ptr = Ptr (
                  C.Functions.Normaliz.new_cone
                    rays_ptr
                    (size_t_of_int num_rays)
                    subspace_gens_ptr
                    (size_t_of_int num_subspace_gens)
                    inequalities_ptr
                    (size_t_of_int num_ineqs)
                    lattice_equations_ptr
                    (size_t_of_int num_eqns)
                    excluded_face_inequalities_ptr
                    (size_t_of_int num_excluded_faces)
                    (* (from_voidp integer null) *)
                    (size_t_of_int dim)
                )
    in ptr

let get_embedding_dimension cone =
  let get_dim cone_ptr =
    let f = C.Functions.Normaliz.get_embedding_dimension in
    FfiLib.int_of_size_t (f cone_ptr) in
  match cone with
  | Ptr ptr -> get_dim ptr

let intersect_cone (Ptr c1) (Ptr c2) =
  if get_embedding_dimension (Ptr c1) != get_embedding_dimension (Ptr c2) then
    Result.error "intersect_cone: Dimensions of the two cones do not match"
  else
    Result.ok
      (Ptr (C.Functions.Normaliz.intersect_cone c1 c2))

let dehomogenize (Ptr c) = Ptr (C.Functions.Normaliz.dehomogenize c)

let hull (Ptr c) = C.Functions.Normaliz.hull c

(*
let get_matrix (cone : C.Types.cptr) (name: string) =
  let f = foreign name (cptr @-> returning (ptr FfiLib.two_dim_array)) in
  let ptr = f cone in
  if is_null ptr then
    []
  else
  let arr = !@ ptr in
  FfiLib.zz_matrix_of_two_dim_array arr
 *)

let to_matrix ptr =
  if is_null ptr then
    []
  else
    let arr = !@ ptr in
    FfiLib.zz_matrix_of_two_dim_array arr

let get_extreme_rays (Ptr cone) =
  C.Functions.Normaliz.get_extreme_rays cone |> to_matrix

let get_lineality_space (Ptr cone) =
  C.Functions.Normaliz.get_lineality_space cone |> to_matrix

let get_inequalities (Ptr cone) =
  C.Functions.Normaliz.get_inequalities cone |> to_matrix

let get_equations (Ptr cone) =
  C.Functions.Normaliz.get_equations cone |> to_matrix

let get_congruences (Ptr cone) =
  C.Functions.Normaliz.get_congruences cone |> to_matrix

let get_vertices (Ptr cone) =
  C.Functions.Normaliz.get_vertices cone |> to_matrix

let get_int_hull_inequalities (Ptr cone) =
  C.Functions.Normaliz.get_integer_hull_inequalities cone |> to_matrix

let get_int_hull_equations (Ptr cone) =
  C.Functions.Normaliz.get_integer_hull_equations cone |> to_matrix

let get_dehomogenization (Ptr cone) =
  C.Functions.Normaliz.get_dehomogenization cone |> to_matrix

let hilbert_basis (Ptr cone) =
  C.Functions.Normaliz.get_hilbert_basis cone |> to_matrix

(* TODO: This really doesn't work well:

   Checking if it is semiopen requires ExcludedFaces to be computed,
   and it fails with an exception when the cone has no excluded faces defined.

let is_semiopen (Hom ptr) =
  foreign "is_semiopen" (cptr @-> returning bool) ptr
*)

let is_empty_semiopen (Ptr ptr) = C.Functions.Normaliz.is_empty_semiopen ptr

let extract_generators_as_constraints (cone : homogeneous cone_ptr) =
  let rays = get_extreme_rays cone in
  let lineality = get_lineality_space cone in
  let dim = get_embedding_dimension cone in
  let equalities = List.concat [lineality ; negate_vectors lineality] in
  let cone' =
    if (rays = []) && (lineality = []) then
      if dim = 0 then empty_cone (* TODO: Check if this is correct *)
      else
        let idm = identity_matrix dim  in
        { rays = [];
          subspace = [];
          inequalities = List.concat [idm ; negate_vectors idm]; (* the origin is the only point *)
          lattice_equations = [];
          excluded_face_inequalities = [];
          ambient_dim = dim }
    else
      { rays = [];
        subspace = [];
        inequalities = List.concat [rays; equalities];
        lattice_equations = [];
        excluded_face_inequalities = [];
        ambient_dim = dim
      }
  in cone'

let generators_to_constraints (cone : homogeneous cone_ptr) =
  new_cone (extract_generators_as_constraints cone)

let is_empty cone = (get_vertices cone = [])

let contains cone vector =
  (* Farkas' lemma:
     Either y^T A = b^T has solution y >= 0, or
     [Ax >= 0 ; b^T x < 0] has solution for x.

     So we turn generators into constraints defining a semi-open polyhedron,
     and check if it is empty.
  *)
  if get_embedding_dimension cone != List.length vector then
    Result.error "contains: dimension doesn't match"
  else
    let cone' = extract_generators_as_constraints cone in
    let strict_ineq = negate_vectors [vector] in
    let cone_ptr = new_cone { cone' with excluded_face_inequalities = strict_ineq } in
    Result.ok (is_empty_semiopen cone_ptr)

(* let foreign_print_cone = foreign "print_cone" (cptr @-> returning void) *)

let pp fmt c =
  let open FfiLib in
  let rays = get_extreme_rays c in
  let lineality_generators = get_lineality_space c in
  let inequalities = get_inequalities c in
  let equations = get_equations c in
  let congruences = get_congruences c in
  Format.fprintf fmt "Printing cone:\n";
  Format.fprintf fmt "Embedding dimension: %d\n" (get_embedding_dimension c);
  Format.fprintf fmt "Rays:\n%a" pp_list_list rays;
  Format.fprintf fmt "Lineality space generators:\n%a"
    pp_list_list lineality_generators;
  Format.fprintf fmt "Inequalities:\n%a" pp_list_list inequalities;
  Format.fprintf fmt "Equations:\n%a" pp_list_list equations;
  Format.fprintf fmt "Congruences:\n%a" pp_list_list congruences

let pp_hom fmt c =
  pp fmt c;
  (* let semiopen = is_semiopen c in
     Format.fprintf fmt "Semiopen?: %b\n" semiopen; *)
  Format.fprintf fmt "Dehomogenization: none\n"

let pp_inhom fmt c =
  let open FfiLib in
  pp fmt c;
  let vertices = get_vertices c in
  let dehom = get_dehomogenization c in
  Format.fprintf fmt "Vertices:\n%a" pp_list_list vertices;
  Format.fprintf fmt "Dehomogenization:\n%a" pp_list_list dehom

let pp_cone fmt c =
  let open FfiLib in
  Format.fprintf fmt "Printing cone:\n";
  Format.fprintf fmt "Rays:\n%a" pp_list_list c.rays;
  Format.fprintf fmt "Subspace:\n%a" pp_list_list c.subspace;
  Format.fprintf fmt "Inequalities:\n%a" pp_list_list c.inequalities;
  Format.fprintf fmt "Lattice equations:\n%a" pp_list_list c.lattice_equations;
  Format.fprintf fmt "Excluded faces:\n%a" pp_list_list c.excluded_face_inequalities;
  Format.fprintf fmt "Ambient dimension:%d" c.ambient_dim

let print_hull_constraints s ineqs_eqns =
  let open FfiLib in
  Format.printf "Cutting plane in/for %s:\n" s;
  Format.printf "Hull inequalities: %a\n" pp_list_list (fst ineqs_eqns);
  Format.printf "Hull equations: %a\n" pp_list_list (snd ineqs_eqns)
