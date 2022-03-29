(* user_command_intf.ml *)

[%%import "/src/config.mlh"]

open Mina_base_import
open Core_kernel
open Snark_params.Tick
open Mina_numbers

module type Gen_intf = sig
  type t

  module Gen : sig
    (** Generate a single transaction between
    * Generate random keys for sender and receiver
    * for fee $\in [Mina_compile_config.minimum_user_command_fee,
    * Mina_compile_config.minimum_user_command_fee+fee_range]$
    * and an amount $\in [1,max_amount]$
    *)
    val payment :
         ?sign_type:[ `Fake | `Real ]
      -> key_gen:
           (Signature_keypair.t * Signature_keypair.t) Quickcheck.Generator.t
      -> ?nonce:Account_nonce.t
      -> max_amount:int
      -> fee_range:int
      -> unit
      -> t Quickcheck.Generator.t

    (** Generate a single transaction between
    * $a, b \in keys$
    * for fee $\in [Mina_compile_config.minimum_user_command_fee,
    * Mina_compile_config.minimum_user_command_fee+fee_range]$
    * and an amount $\in [1,max_amount]$
    *)
    val payment_with_random_participants :
         ?sign_type:[ `Fake | `Real ]
      -> keys:Signature_keypair.t array
      -> ?nonce:Account_nonce.t
      -> max_amount:int
      -> fee_range:int
      -> unit
      -> t Quickcheck.Generator.t

    val stake_delegation :
         key_gen:
           (Signature_keypair.t * Signature_keypair.t) Quickcheck.Generator.t
      -> ?nonce:Account_nonce.t
      -> fee_range:int
      -> unit
      -> t Quickcheck.Generator.t

    val stake_delegation_with_random_participants :
         keys:Signature_keypair.t array
      -> ?nonce:Account_nonce.t
      -> fee_range:int
      -> unit
      -> t Quickcheck.Generator.t

    (** Generate a valid sequence of payments based on the initial state of a
        ledger. Use this together with Ledger.gen_initial_ledger_state.
    *)
    val sequence :
         ?length:int
      -> ?sign_type:[ `Fake | `Real ]
      -> ( Signature_lib.Keypair.t
         * Currency.Amount.t
         * Mina_numbers.Account_nonce.t
         * Account_timing.t )
         array
      -> t list Quickcheck.Generator.t
  end
end

module type S = sig
  type t [@@deriving sexp, yojson, hash]

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  val payload : t -> Signed_command_payload.t

  val fee : t -> Currency.Fee.t

  val nonce : t -> Account_nonce.t

  val signer : t -> Public_key.t

  val fee_token : t -> Token_id.t

  val fee_payer_pk : t -> Public_key.Compressed.t

  val fee_payer : t -> Account_id.t

  val fee_excess : t -> Fee_excess.t

  val token : t -> Token_id.t

  val source_pk : t -> Public_key.Compressed.t

  val source : t -> Account_id.t

  val receiver_pk : t -> Public_key.Compressed.t

  val receiver : t -> Account_id.t

  val public_keys : t -> Public_key.Compressed.t list

  val amount : t -> Currency.Amount.t option

  val memo : t -> Signed_command_memo.t

  val valid_until : t -> Global_slot.t

  (* for filtering *)
  val minimum_fee : Currency.Fee.t

  val has_insufficient_fee : t -> bool

  val tag : t -> Transaction_union_tag.t

  val tag_string : t -> string

  val to_input_legacy :
    Signed_command_payload.t -> (Field.t, bool) Random_oracle_input.Legacy.t

  include Gen_intf with type t := t

  module With_valid_signature : sig
    module Stable : sig
      module Latest : sig
        type nonrec t = private t
        [@@deriving sexp, equal, bin_io, yojson, version, compare, hash]

        include Gen_intf with type t := t
      end

      module V2 = Latest
    end

    type t = Stable.Latest.t [@@deriving sexp, yojson, compare, hash]

    include Gen_intf with type t := t

    include Comparable.S with type t := t
  end

  val sign_payload :
       ?signature_kind:Mina_signature_kind.t
    -> Signature_lib.Private_key.t
    -> Signed_command_payload.t
    -> Signature.t

  val sign :
       ?signature_kind:Mina_signature_kind.t
    -> Signature_keypair.t
    -> Signed_command_payload.t
    -> With_valid_signature.t

  val check_signature : ?signature_kind:Mina_signature_kind.t -> t -> bool

  val create_with_signature_checked :
       ?signature_kind:Mina_signature_kind.t
    -> Signature.t
    -> Public_key.Compressed.t
    -> Signed_command_payload.t
    -> With_valid_signature.t option

  val check_valid_keys : t -> bool

  module For_tests : sig
    (** the signature kind is an argument, to match `sign`, but ignored *)
    val fake_sign :
         ?signature_kind:Mina_signature_kind.t
      -> Signature_keypair.t
      -> Signed_command_payload.t
      -> With_valid_signature.t
  end

  (** checks signature and keys *)
  val check : t -> With_valid_signature.t option

  val check_only_for_signature : t -> With_valid_signature.t option

  val to_valid_unsafe :
       t
    -> [ `If_this_is_used_it_should_have_a_comment_justifying_it of
         With_valid_signature.t ]

  (** Forget the signature check. *)
  val forget_check : With_valid_signature.t -> t

  val accounts_accessed : t -> Account_id.t list

  val filter_by_participant : t list -> Public_key.Compressed.t -> t list

  include Codable.Base58_check_intf with type t := t
end
