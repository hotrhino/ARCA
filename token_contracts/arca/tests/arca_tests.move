
#[test_only]
module loa::arca_tests {

    use loa::arca::{Self, ARCA, Gardian, ExtraCoinMeta, EMaxSupplyExceeded, ENotParticipant, ENotInMultiSigScope};
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self, next_tx, ctx};
    use multisig::multisig::{MultiSignature};
    use std::option::{Self};
    use std::vector;

    // Initialize a mock sender address
    const USER: address = @0xA;
    const PARTICIPANT_SEC: address = @0xB;
    const PARTICIPANT_BOSS: address = @0xC;
    const UNAUTHORIZED: address = @0xF;

    const MINT_AMOUNT:u64 = 1000000000000000;
    
    #[test]
    fun test_mint() {

        // Initialize a mock sender address

        // Begins a multi transaction scenario with USER as the sender
        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario))
        };

        let multi_sign: MultiSignature;
        let gardian: Gardian;
        let extra_coin_meta: ExtraCoinMeta;
        // Mint a `Coin<ARCA>` object
        next_tx(scenario, USER);
        {
            multi_sign = test_scenario::take_shared<MultiSignature>(scenario);
            gardian = test_scenario::take_shared<Gardian>(scenario);
            extra_coin_meta = test_scenario::take_shared<ExtraCoinMeta>(scenario);
            let ctx = test_scenario::ctx(scenario);

            arca::mint_request(&mut gardian, &mut multi_sign, &mut extra_coin_meta, MINT_AMOUNT, USER, ctx);
        };

        // find proposal id from multisig
        let proposal_id: u256;
        test_scenario::next_tx(scenario, USER);
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sign, USER, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };

        // vote for mint
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sign, proposal_id, true, test_scenario::ctx(scenario));
        };

        // mint execute
        test_scenario::next_tx(scenario, USER);
        {            
            arca::mint_execute(&mut gardian,&mut multi_sign, &mut extra_coin_meta, proposal_id, test_scenario::ctx(scenario));
            
        };
        test_scenario::return_shared(multi_sign);
        test_scenario::return_shared(extra_coin_meta);
        test_scenario::return_shared(gardian);
        

        // verify the mint result
        next_tx(scenario, USER);
        {
            let coin_arca:Coin<ARCA> = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
            assert!(coin::value(&coin_arca) == MINT_AMOUNT, 0); 
            test_scenario::return_to_address<Coin<ARCA>>(USER, coin_arca);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

    #[expected_failure(abort_code = EMaxSupplyExceeded)]
    #[test]
    fun test_mint_exceed() {

        // Begins a multi transaction scenario with USER as the sender
        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario))
        };

        let multi_sign: MultiSignature;
        let gardian: Gardian;
        let extra_coin_meta: ExtraCoinMeta;
        // Mint a `Coin<ARCA>` object
        next_tx(scenario, USER);
        {
            multi_sign = test_scenario::take_shared<MultiSignature>(scenario);
            gardian = test_scenario::take_shared<Gardian>(scenario);
            extra_coin_meta = test_scenario::take_shared<ExtraCoinMeta>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let mint_amount = arca::get_max_supply(&mut extra_coin_meta) + 1000;

            arca::mint_request(&mut gardian, &mut multi_sign, &mut extra_coin_meta,  mint_amount, USER, ctx);

            test_scenario::return_shared(multi_sign);
            test_scenario::return_shared(extra_coin_meta);
            test_scenario::return_shared(gardian);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

    #[expected_failure(abort_code = ENotParticipant)]
    #[test]
    fun test_mint_not_participant() {

        // Begins a multi transaction scenario with USER as the sender
        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario))
        };

        let multi_sign: MultiSignature;
        let gardian: Gardian;
        let extra_coin_meta: ExtraCoinMeta;
        // Mint a `Coin<ARCA>` object
        next_tx(scenario, USER);
        {
            multi_sign = test_scenario::take_shared<MultiSignature>(scenario);
        };

        next_tx(scenario, UNAUTHORIZED);
        {
            gardian = test_scenario::take_shared<Gardian>(scenario);
            extra_coin_meta = test_scenario::take_shared<ExtraCoinMeta>(scenario);

            arca::mint_request(&mut gardian, &mut multi_sign, &mut extra_coin_meta,  1000, UNAUTHORIZED, test_scenario::ctx(scenario));
            test_scenario::return_shared(extra_coin_meta);
            test_scenario::return_shared(gardian);
        };

        test_scenario::return_shared(multi_sign);

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

    #[expected_failure(abort_code = ENotInMultiSigScope)]
    #[test]
    fun test_mint_not_in_multisig_scope() {

        // Begins a multi transaction scenario with USER as the sender
        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        let multi_sign: MultiSignature;
        let multi_sign2: MultiSignature;
        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario));
            
        };

        test_scenario::next_tx(scenario, USER);
        {
            multi_sign = test_scenario::take_shared<MultiSignature>(scenario);
        };

        test_scenario::next_tx(scenario, USER);
        {
            multisig::Example::init_for_testing(ctx(scenario));
        };

        test_scenario::next_tx(scenario, USER);
        {
            multi_sign2 = test_scenario::take_shared<MultiSignature>(scenario);
        };
        
        let gardian: Gardian;
        let extra_coin_meta: ExtraCoinMeta;
        test_scenario::next_tx(scenario, USER);
        {
            gardian = test_scenario::take_shared<Gardian>(scenario);
            extra_coin_meta = test_scenario::take_shared<ExtraCoinMeta>(scenario);
            let ctx = test_scenario::ctx(scenario);

            arca::mint_request(&mut gardian, &mut multi_sign2, &mut extra_coin_meta,  1000, USER, ctx);
            test_scenario::return_shared(extra_coin_meta);
            test_scenario::return_shared(gardian);
        };

        test_scenario::return_shared(multi_sign);
        test_scenario::return_shared(multi_sign2);

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mint_multisig() {

        // Begins a multi transaction scenario with USER as the sender
        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario));
        };

        let multi_sign: MultiSignature;
        // set up multisign
        next_tx(scenario, USER);
        {
            multi_sign = test_scenario::take_shared<MultiSignature>(scenario);
            
            let participants = participant_vector();
            let participant_weights = weight_vector();
            let remove = vector::empty<address>();

            multisig::multisig::create_multisig_setting_proposal(&mut multi_sign, b"propose from B", participants, participant_weights, remove, test_scenario::ctx(scenario));
        };

        next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sign, 0, true, test_scenario::ctx(scenario));
        };

        next_tx(scenario, USER);
        {
            multisig::multisig::multisig_setting_execute(&mut multi_sign, 0, test_scenario::ctx(scenario));
        };

        let gardian: Gardian;
        let extra_coin_meta: ExtraCoinMeta;
        next_tx(scenario, USER);
        {
            gardian = test_scenario::take_shared<Gardian>(scenario);
            extra_coin_meta = test_scenario::take_shared<ExtraCoinMeta>(scenario);
            arca::mint_request(&mut gardian, &mut multi_sign, &mut extra_coin_meta, MINT_AMOUNT, USER, test_scenario::ctx(scenario));
        };

        // find proposal id from multisig
        next_tx(scenario, USER);
        let proposal_id: u256;
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sign, USER, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };

        // vote for mint, weight 1/6
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sign, proposal_id, true, test_scenario::ctx(scenario));
        };

        // vote for mint, weight (1+2)/6
        test_scenario::next_tx(scenario, PARTICIPANT_SEC);
        {
            multisig::multisig::vote(&mut multi_sign, proposal_id, true, test_scenario::ctx(scenario));
        };

        // mint execute
        test_scenario::next_tx(scenario, PARTICIPANT_BOSS);
        {            
            arca::mint_execute(&mut gardian,&mut multi_sign, &mut extra_coin_meta, proposal_id, test_scenario::ctx(scenario));
        };
        test_scenario::return_shared(multi_sign);
        test_scenario::return_shared(extra_coin_meta);
        test_scenario::return_shared(gardian);
        

        // verify the mint result
        next_tx(scenario, USER);
        {
            let coin_arca:Coin<ARCA> = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
            assert!(coin::value(&coin_arca) == MINT_AMOUNT, 0); 
            test_scenario::return_to_address<Coin<ARCA>>(USER, coin_arca);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mint_and_burn() {

        // Begins a multi transaction scenario with USER as the sender
        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        // Run the arca coin module init function
        {
            arca::test_init(ctx(scenario))
        };

        let multi_sign: MultiSignature;
        let gardian: Gardian;
        let extra_coin_meta: ExtraCoinMeta;
        // Mint a `Coin<ARCA>` object
        next_tx(scenario, USER);
        {
            multi_sign = test_scenario::take_shared<MultiSignature>(scenario);
            gardian = test_scenario::take_shared<Gardian>(scenario);
            extra_coin_meta = test_scenario::take_shared<ExtraCoinMeta>(scenario);
            let ctx = test_scenario::ctx(scenario);

            arca::mint_request(&mut gardian, &mut multi_sign, &mut extra_coin_meta, MINT_AMOUNT, USER, ctx);
        };

        // find proposal id from multisig
        let proposal_id: u256;
        test_scenario::next_tx(scenario, USER);
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sign, USER, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };

        // vote for mint
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sign, proposal_id, true, test_scenario::ctx(scenario));
        };

        // mint execute
        test_scenario::next_tx(scenario, USER);
        {            
            arca::mint_execute(&mut gardian,&mut multi_sign, &mut extra_coin_meta, proposal_id, test_scenario::ctx(scenario));
            
        };

        // Burn a `Coin<ARCA>` object
        next_tx( scenario, USER);
        {

            let coin_arca = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // arca::burn(gardian, coin_arca, 10000, ctx);
            arca::burn_request(&mut gardian, &mut multi_sign, coin_arca, option::none(), ctx);
            
            // test_scenario::return_to_sender(coin_arca, ctx);
        };
        // find proposal
        let proposal_id_for_burn: u256;
        test_scenario::next_tx(scenario, USER);
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sign, USER, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id_for_burn = vector::pop_back(&mut proposals);
        };
        // vote for burn
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sign, proposal_id_for_burn, true, test_scenario::ctx(scenario));
        };

        // burn execute
        test_scenario::next_tx(scenario, USER);
        {            
            arca::burn_execute(&mut gardian,&mut multi_sign, &mut extra_coin_meta, proposal_id_for_burn, test_scenario::ctx(scenario));  
        };

        test_scenario::return_shared(multi_sign);
        test_scenario::return_shared(extra_coin_meta);
        test_scenario::return_shared(gardian);

        // // verify the burn result
        // next_tx(scenario, USER);
        // {
        //     let coin_arca:Coin<ARCA> = test_scenario::take_from_sender<Coin<ARCA>>(scenario);
        //     assert!(coin::value(&coin_arca) == 100000, 0); 
        //     test_scenario::return_to_address<Coin<ARCA>>(USER, coin_arca);
        // };

        // Cleans up the scenario object
        test_scenario::end(scenario_val);
    }

    fun participant_vector(): vector<address>{
        let participants = vector::empty<address>();
        // vector::push_back<address>(&mut participants, USER);
        vector::push_back<address>(&mut participants, PARTICIPANT_SEC);
        vector::push_back<address>(&mut participants, PARTICIPANT_BOSS);
        participants
    }

    fun weight_vector(): vector<u64>{
        let weight_v = vector::empty<u64>();
        // vector::push_back<u64>(&mut weight_v, 1);
        vector::push_back<u64>(&mut weight_v, 2);
        vector::push_back<u64>(&mut weight_v, 3);
        weight_v
    }

}