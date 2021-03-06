(* All debug traces are guarded with [if verbose]. *)
let verbose = false

let _squelch_unused_module_warning_ = ()

(** Iterate a function while another function is true.

    Results are collected in reverse order for performance.  Use [List.rev] if you need
    results in the order they were produced. *)
let iter_while_rev : type a. iter:(unit -> a) -> cond:(a -> bool) -> a list =
  fun ~iter ~cond ->
    let rec go sofar =
      let r = iter () in
      if cond r
      then go (r :: sofar)
      else sofar
    in
    go []
;;
