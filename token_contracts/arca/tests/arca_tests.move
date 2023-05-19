
#[test_only]
module loa::arca_tests {

    use loa::arca::{Self, ARCA, Gardian, ExtraCoinMeta};
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self, next_tx, ctx};
    use multisig::multisig::{Self, MultiSignature};
    
    #[test]
    fun test_mint_burn() {

        // Initialize a mock sender address
        let addr1 = @0xA;

        // Begins a multi transaction scenario with addr1 as the sender
        let scenario_val = test_scenario::begin(addr1);
        let scenario = &mut scenario_val;


        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario))
        };

        // Mint a `Coin<ARCA>` object
        next_tx(scenario, addr1);
        {
            let gardian_val = test_scenario::take_shared<Gardian>(scenario);
            let gardian = &mut gardian_val;
            let extra_coin_meta_val = test_scenario::take_shared<ExtraCoinMeta>(scenario);
            let extra_coin_meta = &mut extra_coin_meta_val;
            let ctx = test_scenario::ctx(scenario);

            // TODO switch to multisign
            // arca::grant_role(gardian, addr1, ctx);
            // arca::mint(gardian, extra_coin_meta, 100000, addr1, ctx);

            test_scenario::return_shared(gardian_val);
            test_scenario::return_shared(extra_coin_meta_val);
        };

        // verify the mint result
        next_tx(scenario, addr1);
        {
            let coin_arca:Coin<ARCA> = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
            assert!(coin::value(&coin_arca) == 100000, 0); 
            test_scenario::return_to_address<Coin<ARCA>>(addr1, coin_arca);
        };

        // Burn a `Coin<ARCA>` object
        next_tx( scenario, addr1);
        {
            let gardian_val = test_scenario::take_shared<Gardian>(scenario);
            let gardian = &mut gardian_val;

            let coin_arca = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // TODO switch to multisign
            // arca::burn(gardian, coin_arca, 10000, ctx);
            
            test_scenario::return_shared(gardian_val);
        };

        // verify the burn result
        next_tx(scenario, addr1);
        {
            let coin_arca:Coin<ARCA> = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
            assert!(coin::value(&coin_arca) == 100000, 0); 
            test_scenario::return_to_address<Coin<ARCA>>(addr1, coin_arca);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

}