(** OpenSSL FFI modeled after Rust's OpenSSL FFI
    <https://github.com/sfackler/rust-openssl/blob/master/ssl/ffi.rs>.

    For streaming this stuff, see:
    <http://funcptr.net/2012/04/08/openssl-as-a-filter-%28or-non-blocking-openssl%29/>

    This module is for use with Async, which has no threads. You void your warranty
    by calling any of these functions from multiple threads at the same time.
*)
open Core.Std
open Async.Std
open Ctypes
open Import

module Ssl_error : sig
  type t =
    | Zero_return
    | Want_read
    | Want_write
    | Want_connect
    | Want_accept
    | Want_X509_lookup
    | Syscall_error
    | Ssl_error
  with sexp_of
end

module Ssl_ctx : sig

  type t with sexp_of

  (** Initialize a new SSL context, out of which all SSL connections are allocated. *)
  val create_exn : Version.t -> t

  (** Specifies the locations for the context, at which CA certificates for verification
      purposes are located.  The certificates available via [ca_file] and [ca_path] are
      trusted.

      If [ca_file] is not [None], it points to a file of CA certificates in PEM format.
      It may have more than one certificate.

      If [ca_path] is not [None], it points to a directory containing CA certificates in
      PEM format.  The files each contain one CA certificate.  The certificates in
      [ca_path] are only looked up lazily, not eagarly.

      Prepare the directory [/some/where/certs] containing several CA certificates for use
      as [ca_path]:

      [{
        cd /some/where/certs
        c_rehash .
      }]

      If both [ca_file] and [ca_path] are specified, the certificates in [ca_file] will be
      searched before the certificates in [ca_path]. *)
  val load_verify_locations
    :  ?ca_file:string
    -> ?ca_path:string
    -> t
    -> unit Or_error.t Deferred.t
end

module Bio : sig

  type t with sexp_of

  (** Create a new 'infinite' memory-backed IO queue, to replace a socket that openssl
      traditionally needs. *)
  val create : unit -> t

  (** Write some bytes to a BIO.

      Returns either the amount of data successfully read (if the return value is
      positive) or that no data was successfully read if the result is 0 or -1.  If the
      return value is -2 then the operation is not implemented in the specific BIO
      type. *)
  val read : t -> buf:(char ptr) -> len:int -> int

  (** Read some bytes from a BIO.

      Returns either the amount of data successfully written (if the return value is
      positive) or that no data was successfully written if the result is 0 or -1.  If the
      return value is -2 then the operation is not implemented in the specific BIO
      type. *)
  val write : t -> buf:string -> len:int -> int
end

(* Represents an SSL connection. This follows the naming convention of libopenssl, but
   would perhaps better be named [Connection]. *)
module Ssl : sig

  type t with sexp_of

  (** Creates a new SSL connection, with a memory-backed BIO. *)
  val create_exn : Ssl_ctx.t -> t

  (** Sets a different crypto method for this particular ssl connection. *)
  val set_method : t -> Version.t -> unit

  (** Prepare the ssl connection for an initial handshake - either as a server ([`Accept])
      or as a client ([`Connect]). *)
  val set_initial_state : t -> [ `Connect | `Accept ] -> unit

  val connect : t -> (unit, Ssl_error.t) Result.t
  val accept  : t -> (unit, Ssl_error.t) Result.t

  (** Set the binary IO buffers associated with an SSL connection. *)
  val set_bio : t -> input:Bio.t -> output:Bio.t -> unit

  (** Read from the SSL application side. *)
  val read : t -> buf:(char ptr) -> len:int -> (int, Ssl_error.t) Result.t

  (** Write to the SSL application side. *)
  val write : t -> buf:string -> len:int -> (int, Ssl_error.t) Result.t

  (** Use a certificate file, signed by a CA (or self-signed if you prefer) to validate
      you are who you say you are.  The file will generally end in [.crt].

      The 'type' is the encoding of your certificate file. You should know this! *)
  val use_certificate_file
    :  t
    -> crt:string
    -> file_type:[ `PEM | `ASN1 ]
    -> (unit, string list) Result.t Deferred.t

  (** For servers, use a private key [key] for securing communications.

      > openssl genrsa -out server.key 4096 # generates a key called server.key

      The file will generally end in [.key].

      The 'type' is the encoding of your certificate file.  You should know this! *)
  val use_private_key_file
    :  t
    -> key:string
    -> file_type:[ `PEM | `ASN1 ]
    -> (unit, string list) Result.t Deferred.t
end

(** Pops all errors off of the openssl error stack, returning them as a list of
    human-readable strings.  The most recent errors will be at the head of the list. *)
val get_error_stack : unit -> string list
