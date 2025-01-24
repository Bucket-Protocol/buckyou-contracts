module buckyou_core::profile;

//***********************
//  Dependencies
//***********************

use std::type_name::{TypeName};
use sui::vec_map::{Self, VecMap};
use buckyou_core::user_state::{UserState};

//***********************
//  Object
//***********************

public struct Profile has copy, drop, store {
    shares: u64,
    states: VecMap<TypeName, UserState>,
    referrer: Option<address>,
    referral_score: u64,
}

//***********************
//  Package Funs
//***********************

public(package) fun new(referrer: Option<address>): Profile {
    Profile {
        shares: 0,
        states: vec_map::empty(),
        referrer,
        referral_score: 0,
    }
}

public(package) fun states_mut(profile: &mut Profile): &mut VecMap<TypeName, UserState> {
    &mut profile.states
}

public(package) fun add_shares(profile: &mut Profile, shares: u64): u64 {
    let result = profile.shares() + shares;
    profile.shares = result;
    result
}

public(package) fun set_referrer(profile: &mut Profile, referrer: address) {
    if (profile.referrer().is_none()) {
        profile.referrer.fill(referrer);
    }
}

public(package) fun add_score(profile: &mut Profile) {
    profile.referral_score = profile.referral_score() + 1;
}

//***********************
//  Getter Funs
//***********************

public fun shares(profile: &Profile): u64 {
    profile.shares
}

public fun states(profile: &Profile): &VecMap<TypeName, UserState> {
    &profile.states
}

public fun referrer(profile: &Profile): Option<address> {
    profile.referrer
}

public fun referral_score(profile: &Profile): u64 {
    profile.referral_score
}

//***********************
//  Unit Tests
//***********************

#[test]
fun test_profile() {
    let mut profile = new(option::none());
    assert!(profile.shares() == 0);
    assert!(profile.states().size() == 0);
    assert!(profile.referrer().is_none());
    assert!(profile.referral_score() == 0);

    let referrer_1 = @0x123;
    profile.add_shares(10);
    profile.add_score();
    profile.set_referrer(referrer_1);
    assert!(profile.shares() == 10);
    assert!(*profile.referrer().borrow() == referrer_1);
    assert!(profile.referral_score() == 1);

    let referrer_2 = @0x321;
    profile.add_shares(23);
    profile.add_score();
    profile.set_referrer(referrer_2);
    assert!(profile.shares() == 33);
    assert!(*profile.referrer().borrow() == referrer_1);
    assert!(profile.referral_score() == 2);
}