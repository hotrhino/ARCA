module loa::arca{
    use std::string;
    use std::ascii;
    use std::option::{Self, Option};

    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use multisig::multisig::{Self, MultiSignature};

    struct ARCA has drop {}

    const MaxSupply:u64 = 2000000000000000000;

    const MintOperation: u64 = 1;
    const BurnOperation: u64 = 2;
    const UpdateMetadataOperation: u64 = 3;

    /// For when an attempting to interact with another account's Gardian.
    const ENotInMultiSigScope:u64 = 1;
    const ENotParticipant: u64 = 2;
    /// For when mint value exceed the max supply
    const EMaxSupplyExceeded: u64 = 3;
    

    struct Gardian has key, store {
        id: UID,
        treasury_cap: TreasuryCap<ARCA>,
        for_multi_sign: ID,
    }

    struct ExtraCoinMeta has key, store {
        id: UID,
        max_supply: u64,
    }

    // ====== internal structs ======
    struct MintRequest has key, store {
        id: UID,
        amount: u64,
        recipient: address,
    }

    struct BurnRequest has key, store {
        id: UID,
        coin: Option<Coin<ARCA>>,
        amount: Option<u64>,
    }

    struct UpdateMetadataRequest has key, store {
        id: UID,
        name: Option<string::String>,
        symbol: Option<ascii::String>,
        description: Option<string::String>,
        icon_url: Option<ascii::String>,
        max_supply: Option<u64>,
    }

    // ===== Events =====

    struct RoleGranted has copy, drop {
        cashier: address,
    }

    struct RoleRevoked has copy, drop {
        cashier: address,
    }

    struct CoinMinted has copy, drop {
        cashier: address,
        receipent: address,
        amount: u64,
    }

    struct CoinBurned has copy, drop {
        cashier: address,
    }


    fun init(witness: ARCA, tx: &mut TxContext) {
        let (treasury_cap, coin_meta) = coin::create_currency<ARCA>(witness, 10, b"ARCA", b"ARCA", b"ARCA Token", option::none(), tx);
        let multi_sig = multisig::create_multisig(tx);

        let gardian = Gardian {
            id: object::new(tx), 
            treasury_cap: treasury_cap, 
            for_multi_sign: object::id(&multi_sig)
        };
        transfer::public_share_object(multi_sig);
        transfer::public_share_object(coin_meta);
        transfer::share_object(gardian);
        transfer::share_object(ExtraCoinMeta{
            id: object::new(tx),
            max_supply: MaxSupply
        });

    }

    /// send mint request, wait for the multi signature result to be executed or not
    public entry fun mint_request(gardian: &mut Gardian, multi_signature : &mut MultiSignature,  extra_metadata: &ExtraCoinMeta, amount: u64, recipient: address, tx: &mut TxContext) {

        // Only multi sig gardian
        only_multi_sig_scope(multi_signature, gardian);
        // Only participant
        only_participant(multi_signature, tx);
        // check the max suplly cap
        max_supply_not_exceed(gardian, extra_metadata, amount);

        multisig::create_proposal(multi_signature, b"create to @mint", MintOperation, MintRequest{id: object::new(tx), recipient, amount}, tx);
    }

    /// execute the mint behavior while the multi signature approved
    public entry fun mint_execute(gardian: &mut Gardian,  multi_signature: &mut MultiSignature, extra_metadata: &ExtraCoinMeta, proposal_id: u256,  tx: &mut TxContext) {
        // Only multi sig gardian
        only_multi_sig_scope(multi_signature, gardian);
        // Only participant
        only_participant(multi_signature, tx);

        if (multisig::is_proposal_approved(multi_signature, proposal_id)) {
            let request = multisig::borrow_proposal_request<MintRequest>(multi_signature, proposal_id);
            // final check for the max supply cap
            max_supply_not_exceed(gardian, extra_metadata, request.amount);
            // execute the mint action
            mint(gardian, request.amount, request.recipient, tx);
            multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, tx);
        };

        
    }

    /// Mint `amount` of `Coin` and send it to `recipient`. Invokes `mint_and_transfer()`.
    fun mint(gardian: &mut Gardian, amount: u64, recipient: address, tx: &mut TxContext
    ) {
        coin::mint_and_transfer(&mut gardian.treasury_cap, amount, recipient, tx);

        event::emit(CoinMinted{
            cashier: tx_context::sender(tx), 
            receipent: recipient, 
            amount: amount,
        });

    }

    /// send mint request, wait for the multi signature result to be executed or not
    public entry fun burn_request(gardian: &mut Gardian, multi_signature : &mut MultiSignature,  c: Coin<ARCA>, amount: Option<u64>, tx: &mut TxContext) {
        // Only multi sig gardian
        only_multi_sig_scope(multi_signature, gardian);
        // Only participant
        only_participant(multi_signature, tx);
        
        multisig::create_proposal(
            multi_signature,
            b"create to @burn", 
            BurnOperation, 
            BurnRequest{
                id: object::new(tx), 
                coin: option::some(c), 
                amount: amount
                }, tx);
    }

    /// execute the mint behavior while the multi signature approved
    public entry fun burn_execute(gardian: &mut Gardian,  multi_signature: &mut MultiSignature, _extra_metadata: &ExtraCoinMeta, proposal_id: u256,  tx: &mut TxContext) {
        // Only multi sig gardian
        only_multi_sig_scope(multi_signature, gardian);
        // Only participant
        only_participant(multi_signature, tx);

        if (multisig::is_proposal_approved(multi_signature, proposal_id)) {
            // let request = multisig::borrow_proposal_request<BurnRequest>(multi_signature, proposal_id);
            let request: BurnRequest = multisig::extract_proposal_request<BurnRequest>(multi_signature, proposal_id, tx);
            burn(gardian, request, tx);
            multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, tx);
        }
    }

    fun burn(gardian: &mut Gardian, request: BurnRequest, tx: &mut TxContext) {
        // can only burn the coin belong to the sender

        if (option::is_none(&request.amount)) {
            // burn to destory the whole coin
            coin::burn(&mut gardian.treasury_cap, option::extract(&mut request.coin));
            
        } else {
            // TODO burn part of the coin
            // coin::burn(&mut gardian.treasury_cap, c);
        };
        let BurnRequest {id, coin, amount} = request;
        object::delete(id);
        option::destroy_none(coin);
        option::destroy_none(amount);
        
        event::emit(CoinBurned{ cashier: tx_context::sender(tx)});
    }

    // === Update coin metadata ===

    /// Request Update partical metadata of the coin in `CoinMetadata`
    public entry fun update_metadata_request(
        gardian: &mut Gardian, 
        multi_signature : &mut MultiSignature,  
        name: Option<string::String>,
        symbol: Option<ascii::String>,
        description: Option<string::String>,
        icon_url: Option<ascii::String>,
        max_supply: Option<u64>, 
        tx: &mut TxContext
    ) {

        // Only multi sig gardian
        only_multi_sig_scope(multi_signature, gardian);
        // Only participant
        only_participant(multi_signature, tx);

        multisig::create_proposal(
            multi_signature, 
            b"create to @update_metadata", 
            UpdateMetadataOperation, 
            UpdateMetadataRequest{
                id: object::new(tx), 
                name: name,
                symbol: symbol,
                description: description,
                icon_url: icon_url,
                max_supply: max_supply
                }, tx);
    }

    /// Execute Update partical metadata of the coin in `CoinMetadata`
    public entry fun update_metadata_execute(
        gardian: &mut Gardian,
        multi_signature: &mut MultiSignature, 
        metadata: &mut CoinMetadata<ARCA>, 
        extra_metadata: &mut ExtraCoinMeta,
        proposal_id: u256,  
        tx: &mut TxContext
    ) {
        // Only multi sig gardian
        only_multi_sig_scope(multi_signature, gardian);
        // Only participant
        only_participant(multi_signature, tx);

        // make sure proposal got approved
        if (multisig::is_proposal_approved(multi_signature, proposal_id)) {
            let request = multisig::borrow_proposal_request<UpdateMetadataRequest>(multi_signature, proposal_id);
            update_metadata(gardian, metadata, extra_metadata, request, tx);
            multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, tx);
        };
    }

    /// Update partical metadata of the coin in `CoinMetadata`
    fun update_metadata(
        gardian: &Gardian, 
        metadata: &mut CoinMetadata<ARCA>, 
        extra_metadata: &mut ExtraCoinMeta,
        request: & UpdateMetadataRequest, 
        _tx: &mut TxContext) {
        if (option::is_some(&request.name)) {
            coin::update_name(&gardian.treasury_cap, metadata, *option::borrow(&request.name));
        };
        
        if (option::is_some(&request.symbol)) {
            coin::update_symbol(&gardian.treasury_cap, metadata, *option::borrow(&request.symbol));
        };

        if (option::is_some(&request.description)) {
            coin::update_description(&gardian.treasury_cap, metadata, *option::borrow(&request.description));
        };

        if (option::is_some(&request.icon_url)) {
            coin::update_icon_url(&gardian.treasury_cap, metadata, *option::borrow(&request.icon_url));
        };

        if (option::is_some(&request.max_supply)) {
            extra_metadata.max_supply = *option::borrow(&request.max_supply);
        };
    }

    /// Return the max supply for the Coin
    public fun get_max_supply(extra_metadata: &ExtraCoinMeta): u64 {
        extra_metadata.max_supply
    }

    // === check permission functions ===

    fun only_participant (multi_signature: &MultiSignature, tx: &mut TxContext) {
        assert!(multisig::is_participant(multi_signature, tx_context::sender(tx)), ENotParticipant);
    }

    fun only_multi_sig_scope (multi_signature: &MultiSignature, gardian: &Gardian) {
        assert!(object::id(multi_signature) == gardian.for_multi_sign, ENotInMultiSigScope);
    }

    // check the post total supply not exceed the max supply
    fun max_supply_not_exceed(gardian: &Gardian, extra_metadata: &ExtraCoinMeta, amount: u64) {
        let total_supply = coin::total_supply(&gardian.treasury_cap);
        assert!(total_supply + amount <= extra_metadata.max_supply, EMaxSupplyExceeded);
    }


    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ARCA{}, ctx);
    }

}