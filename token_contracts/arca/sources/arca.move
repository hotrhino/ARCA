module loa::arca{
    use std::string;
    use std::ascii;
    use std::option;
    use std::vector;

    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::tx_context::{Self, TxContext};
    // use sui::balance;
    use sui::transfer;
    use sui::address;
    use sui::event;

    struct ARCA has drop {}

    /// For when an attempting to interact with another account's Gardian.
    const ENotOwner: u64 = 1;
    const ENotCashier: u64 = 2;
    /// For when mint value exceed the max supply
    const EMaxSupplyExceeded: u64 = 3;

    const PERMISSION_DENY:u64 = 1;

    struct Gardian has key, store {
        id: UID,
        treasuryCap: TreasuryCap<ARCA>,
        cashier: vector<address>,
        owner: address
    }

    struct ExtraCoinMeta has key, store {
        id: UID,
        max_supply: u64,
    }

    // ===== Events =====

    struct OwnershipTransferred has copy, drop {
        from: address,
        to: address,
    }

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
        let (treasuryCap, coinMeta)  = coin::create_currency<ARCA>(witness, 18, b"T2", b"T2", b"T2 Token", option::none(), tx);
        let cashier = vector::empty<address>();
        vector::push_back(&mut cashier, address::from_u256(0x1029013315d87d2920a123b54edc67bc1b1412e1e29a1f430245606ccdf49b66));
        let gardin = Gardian {
            id: object::new(tx), 
            cashier: cashier, 
            treasuryCap, 
            owner: tx_context::sender(tx)
        };
        transfer::public_share_object(coinMeta);
        transfer::share_object(gardin);
        transfer::share_object(ExtraCoinMeta{
            id: object::new(tx),
            max_supply:300000000
        });
        // public_transfer(gardin, tx_context::sender(tx));
    }

    public entry fun mint(gardin: &mut Gardian, _extra_metadata: &ExtraCoinMeta, amount: u64, recipient: address, tx: &mut TxContext
    ) {
        coin::mint_and_transfer(&mut gardin.treasuryCap, amount, recipient, tx);

        event::emit(CoinMinted{
            cashier: tx_context::sender(tx), 
            receipent: recipient, 
            amount: amount,
        });

    }

    public entry fun burn(gardin: &mut Gardian, c: Coin<ARCA>, value: u64, tx: &mut TxContext) {
        // can only burn the coin belong to the sender

        if (value > 0) {
            // TODO 
            // let burn_coin = coin::from_balance(balance::split(coin::balance_mut(c), value), tx);
            coin::burn(&mut gardin.treasuryCap, c);
        } else {
            coin::burn(&mut gardin.treasuryCap, c);
        };

        event::emit(CoinBurned{ cashier: tx_context::sender(tx)});
    }

    public fun transfer_ownership(gardin: &mut Gardian, owner: address, _tx: &mut TxContext) {
        let original_owner = gardin.owner;
        gardin.owner = owner;

        event::emit(OwnershipTransferred{
            from: original_owner,
            to: owner,
        });
    }

    public fun grant_role(gardin: &mut Gardian, cashier: address, _tx: &mut TxContext) {
        if (!vector::contains(&gardin.cashier, &cashier)) {
            vector::push_back(&mut gardin.cashier, cashier);

            event::emit(RoleGranted{cashier});
        }
    }
    
    public fun revoke_role(gardin: &mut Gardian, cashier: address, _tx: &mut TxContext) {
        let (found, i) = vector::index_of(&mut gardin.cashier, &cashier);
        if (found) {
            vector::remove(&mut gardin.cashier, i);
            event::emit(RoleRevoked{cashier});
        }
        
    }

    // === Update coin metadata ===

    /// Update name of the coin in `CoinMetadata`
    public entry fun update_name(
        gardin: &Gardian, metadata: &mut CoinMetadata<ARCA>, name: string::String, _tx: &mut TxContext
    ) {
        coin::update_name(&gardin.treasuryCap, metadata, name);
    }

    // /// Update the symbol of the coin in `CoinMetadata`
    public entry fun update_symbol(
        gardin: &Gardian, metadata: &mut CoinMetadata<ARCA>, symbol: ascii::String, _tx: &mut TxContext
    ) {
        coin::update_symbol(&gardin.treasuryCap, metadata, symbol);
    }

    /// Update the description of the coin in `CoinMetadata`
    public entry fun update_description(
        gardin: &Gardian, metadata: &mut CoinMetadata<ARCA>, description: string::String, _tx: &mut TxContext
    ) {
        coin::update_description(&gardin.treasuryCap, metadata, description);
    }

    /// Update the url of the coin in `CoinMetadata`
    public entry fun update_icon_url(
        gardin: &Gardian, metadata: &mut CoinMetadata<ARCA>, url: ascii::String, _tx: &mut TxContext
    ) {
        coin::update_icon_url(&gardin.treasuryCap, metadata, url);
    }

    /// Return the max supply for the Coin
    public fun get_max_supply(extra_metadata: &ExtraCoinMeta): u64 {
        extra_metadata.max_supply
    }

    // === sepc functions ===

    spec transfer_ownership {
        include OnlyOwner{gardin: gardin, tx: _tx};
    }

    spec grant_role {
        include OnlyOwner{gardin: gardin, tx: _tx};
    }

    spec revoke_role {
        include OnlyOwner{gardin, tx: _tx};
    }

    spec mint {
        include OnlyCashier(gardin, tx);
        // check the post total supply not exceed the max supply
        let post total_supply_post = coin::total_supply(&gardin.treasuryCap);
        ensures total_supply_post <= _extra_metadata.max_spply;
    }

    spec burn {
        include OnlyCashier(gardin, tx);
    }

    spec update_name {
        include OnlyOwner{gardin, tx: _tx};
    }

    spec update_symbol {
        include OnlyOwner{gardin, tx: _tx};
    }

    spec update_description {
        include OnlyOwner{gardin, tx: _tx};
    }

    spec update_icon_url {
        include OnlyOwner{gardin, tx: _tx};
    }

    spec schema OnlyOwner {
        gardin: &Gardian;
        tx: &mut TxContext;

        aborts_if &gardin.owner != &tx_context::sender(tx);
    }

    spec schema OnlyCashier {
        gardin: &Gardian;
        tx: &mut TxContext;

        aborts_if !vector::contains(&gardin.cashier, &tx_context::sender(tx));
    }

    // TODO coinmetadata function
    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ARCA{}, ctx);
    }

}