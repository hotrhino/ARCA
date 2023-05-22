
#[test_only]
module loa::arca_tests {

    use loa::arca::{Self, ARCA, Gardian, ExtraCoinMeta, EMaxSupplyExceeded};
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self, next_tx, ctx};
    use multisig::multisig::{MultiSignature};
    use std::option::{Self};
    use std::vector;

    const MINT_AMOUNT:u64 = 1000000000000000;
    
    #[test]
    fun test_mint() {

        // Initialize a mock sender address
        let addr1 = @0xA;

        // Begins a multi transaction scenario with addr1 as the sender
        let scenario_val = test_scenario::begin(addr1);
        let scenario = &mut scenario_val;

        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario))
        };

        let multi_sign: MultiSignature;
        let gardian: Gardian;
        let extra_coin_meta: ExtraCoinMeta;
        // Mint a `Coin<ARCA>` object
        next_tx(scenario, addr1);
        {
            multi_sign = test_scenario::take_shared<MultiSignature>(scenario);
            gardian = test_scenario::take_shared<Gardian>(scenario);
            extra_coin_meta = test_scenario::take_shared<ExtraCoinMeta>(scenario);
            let ctx = test_scenario::ctx(scenario);

            arca::mint_request(&mut gardian, &mut multi_sign, &mut extra_coin_meta, MINT_AMOUNT, addr1, ctx);
        };

        // find proposal id from multisig
        let proposal_id: u256;
        test_scenario::next_tx(scenario, addr1);
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sign, addr1, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };

        // vote for mint
        test_scenario::next_tx(scenario, addr1);
        {
            multisig::multisig::vote(&mut multi_sign, proposal_id, true, test_scenario::ctx(scenario));
        };

        // mint execute
        test_scenario::next_tx(scenario, addr1);
        {            
            arca::mint_execute(&mut gardian,&mut multi_sign, &mut extra_coin_meta, proposal_id, test_scenario::ctx(scenario));
            
        };
        test_scenario::return_shared(multi_sign);
        test_scenario::return_shared(extra_coin_meta);
        test_scenario::return_shared(gardian);
        

        // verify the mint result
        next_tx(scenario, addr1);
        {
            let coin_arca:Coin<ARCA> = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
            assert!(coin::value(&coin_arca) == MINT_AMOUNT, 0); 
            test_scenario::return_to_address<Coin<ARCA>>(addr1, coin_arca);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

    #[expected_failure(abort_code = EMaxSupplyExceeded)]
    #[test]
    fun test_mint_exceed() {

        // Initialize a mock sender address
        let addr1 = @0xA;

        // Begins a multi transaction scenario with addr1 as the sender
        let scenario_val = test_scenario::begin(addr1);
        let scenario = &mut scenario_val;

        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario))
        };

        let multi_sign: MultiSignature;
        let gardian: Gardian;
        let extra_coin_meta: ExtraCoinMeta;
        // Mint a `Coin<ARCA>` object
        next_tx(scenario, addr1);
        {
            multi_sign = test_scenario::take_shared<MultiSignature>(scenario);
            gardian = test_scenario::take_shared<Gardian>(scenario);
            extra_coin_meta = test_scenario::take_shared<ExtraCoinMeta>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let mint_amount = arca::get_max_supply(&mut extra_coin_meta) + 1000;

            arca::mint_request(&mut gardian, &mut multi_sign, &mut extra_coin_meta,  mint_amount, addr1, ctx);

            test_scenario::return_shared(multi_sign);
            test_scenario::return_shared(extra_coin_meta);
            test_scenario::return_shared(gardian);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mint_and_burn() {

        // Initialize a mock sender address
        let addr1 = @0xA;

        // Begins a multi transaction scenario with addr1 as the sender
        let scenario_val = test_scenario::begin(addr1);
        let scenario = &mut scenario_val;

        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario))
        };

        let multi_sign: MultiSignature;
        let gardian: Gardian;
        let extra_coin_meta: ExtraCoinMeta;
        // Mint a `Coin<ARCA>` object
        next_tx(scenario, addr1);
        {
            multi_sign = test_scenario::take_shared<MultiSignature>(scenario);
            gardian = test_scenario::take_shared<Gardian>(scenario);
            extra_coin_meta = test_scenario::take_shared<ExtraCoinMeta>(scenario);
            let ctx = test_scenario::ctx(scenario);

            arca::mint_request(&mut gardian, &mut multi_sign, &mut extra_coin_meta, MINT_AMOUNT, addr1, ctx);
        };

        // find proposal id from multisig
        let proposal_id: u256;
        test_scenario::next_tx(scenario, addr1);
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sign, addr1, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };

        // vote for mint
        test_scenario::next_tx(scenario, addr1);
        {
            multisig::multisig::vote(&mut multi_sign, proposal_id, true, test_scenario::ctx(scenario));
        };

        // mint execute
        test_scenario::next_tx(scenario, addr1);
        {            
            arca::mint_execute(&mut gardian,&mut multi_sign, &mut extra_coin_meta, proposal_id, test_scenario::ctx(scenario));
            
        };

        // Burn a `Coin<ARCA>` object
        next_tx( scenario, addr1);
        {

            let coin_arca = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // arca::burn(gardian, coin_arca, 10000, ctx);
            arca::burn_request(&mut gardian, &mut multi_sign, coin_arca, option::none(), ctx);
            
            // test_scenario::return_to_sender(coin_arca, ctx);
        };
        // find proposal
        let proposal_id_for_burn: u256;
        test_scenario::next_tx(scenario, addr1);
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sign, addr1, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id_for_burn = vector::pop_back(&mut proposals);
        };
        // vote for burn
        test_scenario::next_tx(scenario, addr1);
        {
            multisig::multisig::vote(&mut multi_sign, proposal_id_for_burn, true, test_scenario::ctx(scenario));
        };

        // burn execute
        test_scenario::next_tx(scenario, addr1);
        {            
            arca::burn_execute(&mut gardian,&mut multi_sign, &mut extra_coin_meta, proposal_id_for_burn, test_scenario::ctx(scenario));  
        };

        test_scenario::return_shared(multi_sign);
        test_scenario::return_shared(extra_coin_meta);
        test_scenario::return_shared(gardian);

        // // verify the burn result
        // next_tx(scenario, addr1);
        // {
        //     let coin_arca:Coin<ARCA> = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
        //     assert!(coin::value(&coin_arca) == 100000, 0); 
        //     test_scenario::return_to_address<Coin<ARCA>>(addr1, coin_arca);
        // };

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

}