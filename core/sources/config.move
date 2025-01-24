module buckyou_core::config;

//***********************
//  Dependencies
//***********************

use sui::vec_set::{Self, VecSet};
use liquidlogic_framework::float::{Self, Float};
use buckyou_core::admin::{AdminCap};
use buckyou_core::version::{package_version};

//***********************
//  Errors
//***********************

const EInvalidRatio: u64 = 0;
fun err_invalid_ratio() { abort EInvalidRatio }

const EInvalidDistribution: u64 = 1;
fun err_invalid_distribution() { abort EInvalidDistribution }

const EInvalidPackageVersion: u64 = 2;
fun err_invalid_package_version() { abort EInvalidPackageVersion }

//***********************
//  Object
//***********************

public struct Config<phantom P> has key, store {
    id: UID,
    // version
    valid_versions: VecSet<u64>,
    // fund ratio
    final_ratio: Float,
    holders_ratio: Float,
    referrer_ratio: Float,
    // winners
    winner_distribution: vector<Float>,
    // referral
    referral_threshold: u64,
    // status
    initial_countdown: u64,
    time_increment: u64,
    end_time_hard_cap: u64,
}

//***********************
//  Public Funs
//***********************

public fun new<P>(
    cap: &mut AdminCap<P>,
    // fund ratio
    final_ratio: Float,
    holders_ratio: Float,
    referrer_ratio: Float,
    // winners
    winner_distribution: vector<Float>,
    // referral
    referral_threshold: u64,
    // status
    initial_countdown: u64,
    time_increment: u64,
    end_time_hard_cap: u64,
    //
    ctx: &mut TxContext,
): Config<P> {
    // check total ratio == 1
    let total_ratio = final_ratio.add(holders_ratio).add(referrer_ratio);
    if (total_ratio.gt(float::from(1))) {
        err_invalid_ratio();
    };

    // check total winner shares == 1
    let sum_of_winner_distribution =
        winner_distribution
        .fold!(float::from(0), |sum, share| sum.add(share));
    if (sum_of_winner_distribution != float::from(1)) {
        err_invalid_distribution();
    };

    // share config
    let config = Config<P> {
        id: object::new(ctx),
        valid_versions: vec_set::singleton(package_version()),
        final_ratio,
        holders_ratio,
        referrer_ratio,
        winner_distribution,
        referral_threshold,
        initial_countdown,
        time_increment,
        end_time_hard_cap,
    };
    cap.set_config_id(object::id(&config));
    config
}

//***********************
//  Admin Funs
//***********************

public fun add_version<P>(
    config: &mut Config<P>,
    _cap: &AdminCap<P>,
    version: u64,
) {
    if (!config.valid_versions().contains(&version)) {
        config.valid_versions.insert(version);
    };
}

public fun remove_version<P>(
    config: &mut Config<P>,
    _cap: &AdminCap<P>,
    version: u64,
) {
    if (config.valid_versions().contains(&version)) {
        config.valid_versions.remove(&version);
    };
}

//***********************
//  Getter Funs
//***********************

public fun assert_valid_package_version<P>(config: &Config<P>) {
    if (!config.valid_versions().contains(&package_version())) {
        err_invalid_package_version();
    };
}

public fun valid_versions<P>(config: &Config<P>): &VecSet<u64> {
    &config.valid_versions
}

public fun final_ratio<P>(config: &Config<P>): Float {
    config.final_ratio
}

public fun holders_ratio<P>(config: &Config<P>): Float {
    config.holders_ratio
}

public fun referrer_ratio<P>(config: &Config<P>): Float {
    config.referrer_ratio
}

public fun max_winner_count<P>(config: &Config<P>): u64 {
    config.winner_distribution.length()
}

public fun winner_distribution<P>(config: &Config<P>): &vector<Float> {
    &config.winner_distribution
}

public fun referral_threshold<P>(config: &Config<P>): u64 {
    config.referral_threshold
}

public fun initial_countdown<P>(config: &Config<P>): u64 {
    config.initial_countdown
}

public fun time_increment<P>(config: &Config<P>): u64 {
    config.time_increment
}

public fun end_time_hard_cap<P>(config: &Config<P>): u64 {
    config.end_time_hard_cap
}
