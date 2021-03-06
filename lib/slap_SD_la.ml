(* Sized Linear Algebra Package (SLAP)

   Copyright (C) 2013- Akinori ABE <abe@kb.ecei.tohoku.ac.jp>

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*)

(** {2 BLAS interface} *)

(** {3 Level 1} *)

let dot x y =
  Vec.wrap2 (fun ?n ?ofsx ?incx x -> I.dot ?n ?ofsx ?incx x) x y

let asum x = Vec.wrap1 I.asum x

(** {3 Level 2} *)

let sbmv ~k ?y a ?up ?alpha ?beta x =
  let sbs, n, ar, ac, a = M.__expose a in
  let n', ofsx, incx, x = V.__expose x in
  assert(n = n' && sbs = Slap_size.syband_dyn n k);
  let ofsy, incy, y = Slap_vec.opt_vec_alloc prec n y in
  ignore (I.sbmv ~n:(S.__expose n) ~k:(S.__expose k)
            ~ofsy ~incy ~y ~ar ~ac a ?up ?alpha ?beta ~ofsx ~incx x);
  V.__unexpose (n, ofsy, incy, y)

let ger ?(alpha = 1.0) x y a =
  let m, ofsx, incx, x = V.__expose x in
  let n, ofsy, incy, y = V.__expose y in
  let m', n', ar, ac, a = M.__expose a in
  assert(m = m' && n = n');
  ignore (I.ger ~m:(S.__expose m) ~n:(S.__expose n)
              ~alpha ~ofsx ~incx x ~ofsy ~incy y ~ar ~ac a);
  M.__unexpose (m, n, ar, ac, a)

let syr ?(alpha = 1.0) ?(up = true) x a =
  let n, ofsx, incx, x = V.__expose x in
  let n', n'', ar, ac, a = M.__expose a in
  assert(n = n' && n = n'');
  ignore(I.syr ~n:(S.__expose n) ~alpha ~up ~ofsx ~incx x ~ar ~ac a);
  M.__unexpose (n, n, ar, ac, a)

(** {2 LAPACK interface} *)

(** {3 Auxiliary routines} *)

type ('m, 'a) lansy_min_lwork

let lansy_min_lwork n norm =
  S.__unexpose (I.lansy_min_lwork (S.__expose n) (lacaml_norm4 norm))

let lansy ?up ?norm ?work a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  I.lansy ~n:(S.__expose n) ?up ?norm:(lacaml_norm4_opt norm)
    ?work:(Slap_vec.opt_work work) ~ar ~ac a

let lamch = I.lamch

(** {3 Linear equations (computational routines)} *)

(** {4 orgqr} *)

let check_orgqr_args loc k m n =
  if S.__expose m < S.__expose n || S.__expose n < S.__expose k
  then invalid_argf "%s: m >= n >= k" loc ()

type 'n orgqr_min_lwork

let orgqr_min_lwork ~n =
  S.__unexpose (I.orgqr_min_lwork ~n:(S.__expose n))

let orgqr_opt_lwork ~tau a =
  assert(Slap_vec.check_cnt tau);
  let k, _, _, tau = V.__expose tau in
  let m, n, ar, ac, a = M.__expose a in
  check_orgqr_args "orgqr_opt_lwork" k m n;
  I.orgqr_opt_lwork
    ~m:(S.__expose m) ~n:(S.__expose n) ~k:(S.__expose k)
    ~tau ~ar ~ac a
  |> Slap_size.unsafe_of_int

let orgqr_dyn ?work ~tau a =
  assert(Slap_vec.check_cnt tau);
  let k, _, _, tau = V.__expose tau in
  let m, n, ar, ac, a = M.__expose a in
  check_orgqr_args "orgqr_dyn" k m n;
  I.orgqr ~m:(S.__expose m) ~n:(S.__expose n) ~k:(S.__expose k)
    ?work:(Slap_vec.opt_work work) ~tau ~ar ~ac a

(** {4 ormqr} *)

let check_ormqr ~loc ~side ~r ~m ~n ~k ~k' =
  assert(k = k');
  match lacaml_side side with
  | `L ->
    assert(S.__expose r = S.__expose m);
    if S.__expose k > S.__expose m then invalid_argf "%s" loc ()
  | `R ->
    assert(S.__expose r = S.__expose n);
    if S.__expose k > S.__expose m then invalid_argf "%s" loc ()

type ('r, 'm, 'n) ormqr_min_lwork

let ormqr_min_lwork ~side ~m ~n =
  begin
    match lacaml_side side with
    | `L -> max 1 (S.__expose n)
    | `R -> max 1 (S.__expose m)
  end
  |> S.__unexpose

let ormqr_opt_lwork ~side ~trans ~tau a c =
  assert(Slap_vec.check_cnt tau);
  let k, _, _, tau = V.__expose tau in
  let r, k', ar, ac, a = M.__expose a in
  let m, n, cr, cc, c = M.__expose c in
  check_ormqr ~loc:"ormqr_opt_lwork" ~side ~r ~m ~n ~k ~k';
  I.ormqr_opt_lwork ~side:(lacaml_side side) ~trans:(lacaml_trans2 trans)
    ~m:(S.__expose m) ~n:(S.__expose n) ~k:(S.__expose k)
    ~tau ~ar ~ac a ~cr ~cc c
  |> Slap_size.unsafe_of_int

let ormqr_dyn ~side ~trans ?work ~tau a c =
  assert(Slap_vec.check_cnt tau);
  let k, _, _, tau = V.__expose tau in
  let r, k', ar, ac, a = M.__expose a in
  let m, n, cr, cc, c = M.__expose c in
  check_ormqr ~loc:"ormqr_dyn" ~side ~r ~m ~n ~k ~k';
  I.ormqr ~side:(lacaml_side side) ~trans:(lacaml_trans2 trans)
    ~m:(S.__expose m) ~n:(S.__expose n) ~k:(S.__expose k)
    ?work:(Slap_vec.opt_work work) ~tau ~ar ~ac a ~cr ~cc c

(** {4 gecon} *)

type 'n gecon_min_lwork

let gecon_min_lwork n = S.__unexpose (I.gecon_min_lwork (S.__expose n))

type 'n gecon_min_liwork

let gecon_min_liwork n = S.__unexpose (I.gecon_min_liwork (S.__expose n))

let gecon ?norm ?anorm ?work ?iwork a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  I.gecon ~n:(S.__expose n) ?norm:(lacaml_norm2_opt norm) ?anorm
           ?work:(Slap_vec.opt_work work)
           ?iwork:(Slap_vec.opt_work iwork)
           ~ar ~ac a

(** {4 sycon} *)

type 'n sycon_min_lwork

let sycon_min_lwork n = S.__unexpose (I.sycon_min_lwork (S.__expose n))

type 'n sycon_min_liwork

let sycon_min_liwork n = S.__unexpose (I.sycon_min_liwork (S.__expose n))

let sycon ?up ?ipiv ?anorm ?work ?iwork a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  I.sycon ~n:(S.__expose n) ?up ?ipiv:(Slap_vec.opt_cnt_vec n ipiv) ?anorm
    ?work:(Slap_vec.opt_work work)
    ?iwork:(Slap_vec.opt_work iwork)
    ~ar ~ac a

(** {4 pocon} *)

type 'n pocon_min_lwork

let pocon_min_lwork n = S.__unexpose (I.pocon_min_lwork (S.__expose n))

type 'n pocon_min_liwork

let pocon_min_liwork n = S.__unexpose (I.pocon_min_liwork (S.__expose n))

let pocon ?up ?anorm ?work ?iwork a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  I.pocon ~n:(S.__expose n) ?up ?anorm
    ?work:(Slap_vec.opt_work work)
    ?iwork:(Slap_vec.opt_work iwork)
    ~ar ~ac a

(** {3 Least squares (expert drivers)} *)

(** {4 gelsy} *)

type ('m, 'n, 'nrhs) gelsy_min_lwork

let gelsy_min_lwork ~m ~n ~nrhs =
  S.__unexpose (I.gelsy_min_lwork
                    ~m:(S.__expose m) ~n:(S.__expose n)
                    ~nrhs:(S.__expose nrhs))

let gelsy_opt_lwork a b =
  let m, n, ar, ac, a = M.__expose a in
  let n', nrhs, br, bc, b = M.__expose b in
  assert(n = n');
  I.gelsy_opt_lwork ~m:(S.__expose m) ~n:(S.__expose n)
    ~nrhs:(S.__expose nrhs) ~ar ~ac a ~br ~bc b
  |> Slap_size.unsafe_of_int

let gelsy a ?rcond ?jpvt ?work b =
  let m, n, ar, ac, a = M.__expose a in
  let n', nrhs, br, bc, b = M.__expose b in
  assert(n = n');
  I.gelsy ~m:(S.__expose m) ~n:(S.__expose n) ~nrhs:(S.__expose nrhs)
    ?jpvt:(Slap_vec.opt_cnt_vec n jpvt) ?work:(Slap_vec.opt_work work)
     ~ar ~ac a ?rcond ~br ~bc b

(** {4 gelsd} *)

type ('m, 'n, 'nrhs) gelsd_min_lwork

let gelsd_min_lwork ~m ~n ~nrhs =
  S.__unexpose (I.gelsd_min_lwork
                    ~m:(S.__expose m) ~n:(S.__expose n)
                    ~nrhs:(S.__expose nrhs))

let gelsd_opt_lwork a b =
  let m, n, ar, ac, a = M.__expose a in
  let n', nrhs, br, bc, b = M.__expose b in
  assert(n = n');
  I.gelsd_opt_lwork ~m:(S.__expose m) ~n:(S.__expose n)
    ~nrhs:(S.__expose nrhs) ~ar ~ac a ~br ~bc b
  |> Slap_size.unsafe_of_int

type ('m, 'n, 'nrhs) gelsd_min_iwork

let gelsd_min_iwork m n =
  S.__unexpose (I.gelsd_min_iwork (S.__expose m) (S.__expose n))

let gelsd a ?rcond ?s ?work ?iwork b =
  let m, n, ar, ac, a = M.__expose a in
  let n', nrhs, br, bc, b = M.__expose b in
  assert(n = n');
  I.gelsd  ~m:(S.__expose m) ~n:(S.__expose n) ~nrhs:(S.__expose nrhs)
    ~ar ~ac a ?rcond ~br ~bc b ?s:(Slap_vec.opt_cnt_vec (Slap_size.min m n) s)
    ?work:(Slap_vec.opt_work work) ?iwork:(Slap_vec.opt_work iwork)

(** {4 gelss} *)

type ('m, 'n, 'nrhs) gelss_min_lwork

let gelss_min_lwork ~m ~n ~nrhs =
  S.__unexpose (I.gelss_min_lwork
                    ~m:(S.__expose m) ~n:(S.__expose n)
                    ~nrhs:(S.__expose nrhs))

let gelss_opt_lwork a b =
  let m, n, ar, ac, a = M.__expose a in
  let n', nrhs, br, bc, b = M.__expose b in
  assert(n = n');
  I.gelss_opt_lwork
    ~m:(S.__expose m) ~n:(S.__expose n) ~nrhs:(S.__expose nrhs)
    ~ar ~ac a ~br ~bc b
  |> Slap_size.unsafe_of_int

let gelss a ?rcond ?s ?work b =
  let m, n, ar, ac, a = M.__expose a in
  let n', nrhs, br, bc, b = M.__expose b in
  assert(n = n');
  I.gelss ~m:(S.__expose m) ~n:(S.__expose n) ~nrhs:(S.__expose nrhs)
    ~ar ~ac a ?rcond ~br ~bc b
    ?s:(Slap_vec.opt_cnt_vec (Slap_size.min m n) s)
    ?work:(Slap_vec.opt_work work)

(** {3 General SVD routines} *)

(** {4 gesvd} *)

type ('m, 'n) gesvd_min_lwork

let gesvd_min_lwork ~m ~n =
  S.__unexpose (I.gesvd_min_lwork ~m:(S.__expose m) ~n:(S.__expose n))

let gesvd_calc_sizes m n jobu jobvt =
  let min_mn = Slap_size.min m n in
  let job_size c = function
    | `A -> S.__expose c
    | `S -> S.__expose min_mn
    | `O | `N -> 0 in
  let u_cols = S.__unexpose (job_size m (lacaml_svd_job jobu)) in
  let vt_rows = S.__unexpose (job_size n (lacaml_svd_job jobvt)) in
  (min_mn, u_cols, vt_rows)

let gesvd_opt_lwork ~jobu ~jobvt ?s ?u ?vt a =
  let m, n, ar, ac, a = M.__expose a in
  let min_mn, u_cols, vt_rows = gesvd_calc_sizes m n jobu jobvt in
  let ur, uc, u = Slap_mat.opt_mat m u_cols u in
  let vtr, vtc, vt = Slap_mat.opt_mat vt_rows n vt in
  I.gesvd_opt_lwork ~m:(S.__expose m) ~n:(S.__expose n)
    ~jobu:(lacaml_svd_job jobu) ~jobvt:(lacaml_svd_job jobvt)
    ?s:(Slap_vec.opt_cnt_vec min_mn s) ?ur ?uc ?u ?vtr ?vtc ?vt ~ar ~ac a
  |> Slap_size.unsafe_of_int

let gesvd ~jobu ~jobvt ?s ?u ?vt ?work a =
  let m, n, ar, ac, a = M.__expose a in
  let min_mn, u_cols, vt_rows = gesvd_calc_sizes m n jobu jobvt in
  let ur, uc, u = Slap_mat.opt_mat_alloc prec m u_cols u in
  let vtr, vtc, vt = Slap_mat.opt_mat_alloc prec vt_rows n vt in
  let s, u, vt = I.gesvd ~m:(S.__expose m) ~n:(S.__expose n)
      ~jobu:(lacaml_svd_job jobu) ~jobvt:(lacaml_svd_job jobvt)
      ?s:(Slap_vec.opt_cnt_vec min_mn s) ~ur ~uc ~u ~vtr ~vtc ~vt
      ?work:(Slap_vec.opt_work work) ~ar ~ac a in
  (V.__unexpose (min_mn, 1, 1, s),
   M.__unexpose (m, u_cols, ur, uc, u),
   M.__unexpose (vt_rows, n, vtr, vtc, vt))

(** {4 gesdd} *)

type ('m, 'n) gesdd_liwork

let gesdd_liwork ~m ~n =
  S.__unexpose (I.gesdd_liwork ~m:(S.__expose m) ~n:(S.__expose n))

type ('m, 'n, 'jobz) gesdd_min_lwork

let gesdd_min_lwork ~jobz ~m ~n () =
  S.__unexpose (I.gesdd_min_lwork ~jobz:(lacaml_svd_job jobz)
                    ~m:(S.__expose m) ~n:(S.__expose n) ())

let gesdd_calc_sizes m n jobz =
  let m = S.__expose m in
  let n = S.__expose n in
  match lacaml_svd_job jobz with
  | `A -> (m, n)
  | `S -> let k = min m n in (k, k)
  | `O -> if m >= n then (0, n) else (m, 0)
  | `N -> (0, 0)

let gesdd_opt_lwork ~jobz ?s ?u ?vt ?iwork a =
  let m, n, ar, ac, a = M.__expose a in
  let min_mn = Slap_size.min m n in
  let u_cols, vt_rows = gesdd_calc_sizes m n jobz in
  let ur, uc, u = Slap_mat.opt_mat m (S.__unexpose u_cols) u in
  let vtr, vtc, vt = Slap_mat.opt_mat (S.__unexpose vt_rows) n vt in
  I.gesdd_opt_lwork ~m:(S.__expose m) ~n:(S.__expose m)
    ~jobz:(lacaml_svd_job jobz) ?s:(Slap_vec.opt_cnt_vec min_mn s)
    ?iwork:(Slap_vec.opt_work iwork)
    ?ur ?uc ?u ?vtr ?vtc ?vt ~ar ~ac a
  |> Slap_size.unsafe_of_int

let gesdd ~jobz ?s ?u ?vt ?work ?iwork a =
  let m, n, ar, ac, a = M.__expose a in
  let min_mn = Slap_size.min m n in
  let _gesdd ?ur ?uc ?u ?vtr ?vtc ?vt () =
    I.gesdd ~m:(S.__expose m) ~n:(S.__expose n) ~jobz:(lacaml_svd_job jobz)
      ?s:(Slap_vec.opt_cnt_vec min_mn s) ?work:(Slap_vec.opt_work work)
      ?iwork:(Slap_vec.opt_work iwork) ?ur ?uc ?u ?vtr ?vtc ?vt ~ar ~ac a
  in
  let opt_mat_alloc m n a = Slap_mat.opt_mat_alloc prec m n a in
  let mks s = V.__unexpose (min_mn, 1, 1, s) in
  let mku u_cols ur uc u =
    Some (M.__unexpose (m, S.__unexpose u_cols, ur, uc, u)) in
  let mkvt vt_rows vtr vtc vt =
    Some (M.__unexpose (S.__unexpose vt_rows, n, vtr, vtc, vt)) in
  match gesdd_calc_sizes m n jobz with
  | 0, 0 ->
    let s, _, _ = _gesdd () in
    (mks s, None, None)
  | 0, vt_rows ->
    let vtr, vtc, vt = opt_mat_alloc (S.__unexpose vt_rows) n vt in
    let s, _, vt = _gesdd ~vtr ~vtc ~vt () in
    (mks s, None, mkvt vt_rows vtr vtc vt)
  | u_cols, 0 ->
    let ur, uc, u = opt_mat_alloc m (S.__unexpose u_cols) u in
    let s, u, _ = _gesdd ~ur ~uc ~u () in
    (mks s, mku u_cols ur uc u, None)
  | u_cols, vt_rows ->
    let ur, uc, u = opt_mat_alloc m (S.__unexpose u_cols) u in
    let vtr, vtc, vt = opt_mat_alloc (S.__unexpose vt_rows) n vt in
    let s, u, vt = _gesdd ~ur ~uc ~u ~vtr ~vtc ~vt () in
    (mks s, mku u_cols ur uc u, mkvt vt_rows vtr vtc vt)

(** {3 General eigenvalue problem (simple drivers)} *)

(** {4 geev} *)

let geev_min_lwork ?vectors n =
  I.geev_min_lwork ?vectors (S.__expose n)
  |> Slap_size.unsafe_of_int

let geev_opt_lwork ?vl ?vr ?wr ?wi a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  let make_arg = function
    | Some (Some x) ->
      let xn, xn', xr, xc, x = M.__expose x in
      assert(n = xn && n = xn');
      Some xr, Some xc, Some (Some x)
    | Some None -> None, None, Some None
    | None -> None, None, None
  in
  let vlr, vlc, vl = make_arg vl in
  let vrr, vrc, vr = make_arg vr in
  I.geev_opt_lwork ~n:(S.__expose n) ?vlr ?vlc ?vl ?vrr ?vrc ?vr
    ?wr:(Slap_vec.opt_cnt_vec n wr) ?wi:(Slap_vec.opt_cnt_vec n wi) ~ar ~ac a
  |> Slap_size.unsafe_of_int

let geev ?work ?vl ?vr ?wr ?wi a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  let make_conv_and_arg = function
    | Some (Some x) ->
      let xn, xn', xr, xc, x = M.__expose x in
      assert(n = xn && n = xn');
      let conv x = Some (M.__unexpose (n, n, xr, xc, x)) in
      (conv, Some xr, Some xc, Some (Some x))
    | Some None ->
      let conv x = Some (M.__unexpose (n, n, 1, 1, x)) in
      (conv, None, None, Some None)
    | None -> ((fun _ -> None), None, None, None)
  in
  let conv_vl, vlr, vlc, vl = make_conv_and_arg vl in
  let conv_vr, vrr, vrc, vr = make_conv_and_arg vr in
  let vl, wr, wi, vr = I.geev ~n:(S.__expose n)
      ?work:(Slap_vec.opt_work work) ?vlr ?vlc ?vl ?vrr ?vrc ?vr
      ?wr:(Slap_vec.opt_cnt_vec n wr) ?wi:(Slap_vec.opt_cnt_vec n wi)
      ~ar ~ac a in
  let vl = conv_vl vl in
  let vr = conv_vr vr in
  let wr = V.__unexpose (n, 1, 1, wr) in
  let wi = V.__unexpose (n, 1, 1, wi) in
  (vl, wr, wi, vr)

(** {3 Symmetric-matrix eigenvalue and singular value problems
         (simple drivers)} *)

(** {4 syev} *)

type 'n syev_min_lwork

let syev_min_lwork n = S.__unexpose (I.syev_min_lwork (S.__expose n))

let syev_opt_lwork ?vectors ?up a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  I.syev_opt_lwork ~n:(S.__expose n) ?vectors ?up ~ar ~ac a
  |> Slap_size.unsafe_of_int

let syev ?vectors ?up ?work ?w a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  let w = Slap_vec.opt_cnt_vec_alloc prec n w in
  ignore (I.syev ~n:(S.__expose n) ?vectors ?up
            ?work:(Slap_vec.opt_work work) ~w ~ar ~ac a);
  V.__unexpose (n, 1, 1, w)

(** {4 syevd} *)

let syevd_min_lwork ~vectors n =
  I.syevd_min_lwork ~vectors (S.__expose n)
  |> Slap_size.unsafe_of_int

let syevd_min_liwork ~vectors n =
  I.syevd_min_liwork ~vectors (S.__expose n)
  |> Slap_size.unsafe_of_int

let syevd_opt_lwork ?vectors ?up a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  I.syevd_opt_lwork ~n:(S.__expose n) ?vectors ?up ~ar ~ac a
  |> Slap_size.unsafe_of_int

let syevd_opt_liwork ?vectors ?up a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  I.syevd_opt_liwork ~n:(S.__expose n) ?vectors ?up ~ar ~ac a
  |> Slap_size.unsafe_of_int

let syevd ?vectors ?up ?work ?iwork ?w a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  let w = I.syevd ~n:(S.__expose n) ?vectors ?up
      ?work:(Slap_vec.opt_work work) ?iwork:(Slap_vec.opt_work iwork)
      ?w:(Slap_vec.opt_cnt_vec n w) ~ar ~ac a in
  V.__unexpose (n, 1, 1, w)

(** {4 sbev} *)

type 'n sbev_min_lwork

let sbev_min_lwork n =
  S.__unexpose (I.sbev_min_lwork (S.__expose n))

let sbev ~kd ?z ?up ?work ?w ab =
  let sbsize, n, abr, abc, ab = M.__expose ab in
  assert(sbsize = Slap_size.syband_dyn n kd);
  let zr, zc, z = Slap_mat.opt_mat_alloc prec n n z in
  let w = I.sbev ~n:(S.__expose n) ~kd:(S.__expose kd) ~zr ~zc ~z ?up
      ?work:(Slap_vec.opt_work work) ?w:(Slap_vec.opt_cnt_vec n w)
      ~abr ~abc ab in
  V.__unexpose (n, 1, 1, w)

(** {3 Symmetric-matrix eigenvalue and singular value problems
       (expert & RRR drivers)} *)

(** {4 syevr} *)


type 'n syevr_min_lwork

let syevr_min_lwork n =
  S.__unexpose (I.syevr_min_lwork (S.__expose n))

type 'n syevr_min_liwork

let syevr_min_liwork n =
  S.__unexpose (I.syevr_min_liwork (S.__expose n))

let syevr_opt_lwork ?vectors ?range ?up ?abstol a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  I.syevr_opt_lwork ~n:(S.__expose n) ?vectors ?range ?up ?abstol ~ar ~ac a
  |> Slap_size.unsafe_of_int

let syevr_opt_liwork ?vectors ?range ?up ?abstol a =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  I.syevr_opt_liwork ~n:(S.__expose n) ?vectors ?range ?up ?abstol ~ar ~ac a
  |> Slap_size.unsafe_of_int

module type SYEVR_RESULT =
  sig
    type m
    type n
    val value : m Slap_size.t *
                (n, 'cnt) vec *
                (n, m, 'cnt) mat *
                ((m, m) Slap_size.add, 'cnt) Slap_common.int32_vec
  end

let syevr_dyn (type nn) ?vectors ?range ?up ?abstol ?work ?iwork ?w ?z ?isuppz
    (a : (nn, nn, 'a_cd) mat) =
  let n, n', ar, ac, a = M.__expose a in
  assert(n = n');
  let syevr k ?zr ?zc ?z ar ac a =
    I.syevr ~n:(S.__expose n) ?vectors ?range ?up ?abstol
      ?work:(Slap_vec.opt_work work) ?iwork:(Slap_vec.opt_work iwork)
      ?w:(Slap_vec.opt_cnt_vec n w)
      ?isuppz:(Slap_vec.opt_cnt_vec (Slap_size.add k k) isuppz)
      ?zr ?zc ?z ~ar ~ac a in
  let res = match z with
    | Some z ->
      let n'', k, zr, zc, z = M.__expose z in
      assert(n = n'');
      let (m, w, z, isuppz) = syevr k ~zr ~zc ~z ar ac a in
      if m > S.__expose k
      then invalid_argf "syevr_dyn: m (= %d) should be smaller than k (= %d)"
          m (S.__expose k) ();
      (S.__unexpose m,
       V.__unexpose (n, 1, 1, w),
       M.__unexpose (n, S.__unexpose m, zr, zc, z),
       V.__unexpose (S.__unexpose (2 * m), 1, 1, isuppz))
    | None ->
      let (m, w, z, isuppz) = syevr (S.__unexpose (S.__expose n)) ar ac a in
      (S.__unexpose m,
       V.__unexpose (n, 1, 1, w),
       M.__unexpose (n, S.__unexpose (Array2.dim2 z), 1, 1, z),
       V.__unexpose (S.__unexpose (Array1.dim isuppz), 1, 1, isuppz)) in
  let module R =
    struct
      type n = nn
      type m
      let value = res
    end in
  (module R : SYEVR_RESULT with type n = nn)

(** {4 sygv} *)

let sygv_opt_lwork ?vectors ?up ?itype a b =
  let n, n', ar, ac, a = M.__expose a in
  let n'', n''', br, bc, b = M.__expose b in
  assert(n = n' && n = n'' && n = n''');
  I.sygv_opt_lwork ~n:(S.__expose n) ?vectors ?up ?itype ~ar ~ac a ~br ~bc b
  |> Slap_size.unsafe_of_int

let sygv ?vectors ?up ?work ?w ?itype a b =
  let n, n', ar, ac, a = M.__expose a in
  let n'', n''', br, bc, b = M.__expose b in
  assert(n = n' && n = n'' && n = n''');
  let w = I.sygv ~n:(S.__expose n) ?vectors ?up ?work:(Slap_vec.opt_work work)
                 ?w:(Slap_vec.opt_cnt_vec n w) ?itype ~ar ~ac a ~br ~bc b in
  V.__unexpose (n, 1, 1, w)

(** {4 sbgv} *)

let sbgv ~ka ~kb ?z ?up ?work ?w ab bb =
  let sbsize_a, n, abr, abc, ab = M.__expose ab in
  let sbsize_b, n', bbr, bbc, bb = M.__expose bb in
  assert(n = n');
  assert(sbsize_a = Slap_size.syband_dyn n ka);
  assert(sbsize_b = Slap_size.syband_dyn n kb);
  let zr, zc, z = Slap_mat.opt_mat_alloc prec n n z in
  let w = I.sbgv ~n:(S.__expose n) ~ka:(S.__expose ka) ~kb:(S.__expose kb)
      ~zr ~zc ~z ?up ?work:(Slap_vec.opt_work work)
      ?w:(Slap_vec.opt_cnt_vec n w) ~ar:abr ~ac:abc ab ~br:bbr ~bc:bbc bb in
  V.__unexpose (n, 1, 1, w)
