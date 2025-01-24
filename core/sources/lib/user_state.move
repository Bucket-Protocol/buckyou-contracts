module buckyou_core::user_state;

//***********************
//  Dependencies
//***********************

use liquidlogic_framework::double::{Float};

//***********************
//  Errors
//***********************

const ENotEnoughToClaim: u64 = 0;
fun err_not_enough_to_claim() { abort ENotEnoughToClaim }

//***********************
//  Struct
//***********************

public struct UserState has store, copy, drop {
    unit: Float,
    holders_reward: u64,
    referral_reward: u64,
}

//***********************
//  Package Funs
//***********************

public(package) fun new(unit: Float): UserState {
    UserState { unit, holders_reward: 0, referral_reward: 0 } 
}

public(package) fun set_unit(state: &mut UserState, unit: Float) {
    state.unit = unit;
}

public(package) fun settle(state: &mut UserState, amount: u64): u64 {
    let result = state.holders_reward() + amount;
    state.holders_reward = result;
    result
}

public(package) fun rebate(state: &mut UserState, amount: u64): u64 {
    let result = state.referral_reward() + amount;
    state.referral_reward = result;
    result
}

public(package) fun claim(state: &mut UserState, amount: u64): (u64, u64) {
    if (state.total_reward() < amount) {
        err_not_enough_to_claim();
    };
    if (state.holders_reward() >= amount) {
        state.holders_reward = state.holders_reward() - amount;
    } else {
        let shortage = amount - state.holders_reward();
        state.holders_reward = 0;
        state.referral_reward = state.referral_reward() - shortage;
    };
    (state.holders_reward(), state.referral_reward())
}


//***********************
//  Getter Funs
//***********************

public fun unit(state: &UserState): Float {
    state.unit
}

public fun holders_reward(state: &UserState): u64 {
    state.holders_reward
}

public fun referral_reward(state: &UserState): u64 {
    state.referral_reward
}

public fun total_reward(state: &UserState): u64 {
    state.holders_reward() + state.referral_reward()
}

//***********************
//  Unit Tests
//***********************

#[test]
fun test_user_state() {
    use liquidlogic_framework::double;
    let init_unit = double::from_bps(150);
    let mut user_state = new(init_unit);
    assert!(user_state.unit() == init_unit);
    assert!(user_state.holders_reward() == 0);
    assert!(user_state.referral_reward() == 0);
    assert!(user_state.total_reward() == 0);
    
    let pool_unit = double::from_percent(2);
    user_state.set_unit(pool_unit);
    user_state.settle(1_000_000);
    user_state.rebate(2_000_000);
    assert!(user_state.unit() == pool_unit);
    assert!(user_state.holders_reward() == 1_000_000);
    assert!(user_state.referral_reward() == 2_000_000);
    assert!(user_state.total_reward() == 3_000_000);

    user_state.settle(500_000);
    user_state.rebate(700_000);
    assert!(user_state.unit() == pool_unit);
    assert!(user_state.holders_reward() == 1_500_000);
    assert!(user_state.referral_reward() == 2_700_000);
    assert!(user_state.total_reward() == 4_200_000);

    user_state.claim(900_000);
    assert!(user_state.holders_reward() == 600_000);
    assert!(user_state.referral_reward() == 2_700_000);
    assert!(user_state.total_reward() == 3_300_000);

    user_state.claim(1_300_000);
    assert!(user_state.holders_reward() == 0);
    assert!(user_state.referral_reward() == 2_000_000);
    assert!(user_state.total_reward() == 2_000_000);

    let total_reward = user_state.total_reward();
    user_state.claim(total_reward);
    assert!(user_state.holders_reward() == 0);
    assert!(user_state.referral_reward() == 0);
    assert!(user_state.total_reward() == 0);    
}

#[test, expected_failure(abort_code = ENotEnoughToClaim)]
fun test_not_enough_to_claim() {
    use liquidlogic_framework::double;
    let init_unit = double::from_bps(150);
    let mut user_state = new(init_unit);
    user_state.settle(1_000);
    user_state.rebate(4_000);

    let total_reward = user_state.total_reward();
    assert!(total_reward == 5_000);
    user_state.claim(total_reward + 1);
}
