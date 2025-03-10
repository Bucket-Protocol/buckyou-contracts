module buckyou_core::step_price;

//***********************
//  Dependencies
//***********************

use sui::clock::{Clock};
use liquidlogic_framework::float::{Self, Float};
use buckyou_core::admin::{AdminCap};
use buckyou_core::pool::{Pool};
use buckyou_core::status::{Status};

//***********************
//  Witness
//***********************

public struct STEP_PRICE_RULE has drop {}

//***********************
//  Objects
//***********************

public struct Rule<phantom P, phantom T> has key, store {
    id: UID,
    initial_price: u64,
    period: u64,
    price_increment: u64,
    factor: Float,
}

//***********************
//  Admin Funs
//***********************

public fun new<P, T>(
    _cap: &AdminCap<P>,
    initial_price: u64,
    period: u64,
    price_increment: u64,
    factor: Float,
    ctx: &mut TxContext,
): Rule<P, T> {
    Rule<P, T> {
        id: object::new(ctx),
        initial_price,
        period,
        price_increment,
        factor
    }
}

public fun set_factor<P, T>(
    rule: &mut Rule<P, T>,
    _cap: &AdminCap<P>,
    percent: u64,
) {
    rule.factor = float::from_percent_u64(percent);
}

public fun destroy<P, T>(
    rule: Rule<P, T>,
    _cap: &AdminCap<P>,
) {
    let Rule {
        id,
        initial_price: _,
        period: _,
        price_increment: _,
        factor: _,
    } = rule;
    id.delete();
}

//***********************
//  Public Funs
//***********************

public fun update_price<P, T>(
    rule: &Rule<P, T>,
    status: &Status<P>,
    pool: &mut Pool<P, T>,
    clock: &Clock,
) {
    let price = rule.price(status, clock);
    pool.update_price(clock, STEP_PRICE_RULE {}, price);
}

//***********************
//  Getter Funs
//***********************

public fun price<P, T>(
    rule: &Rule<P, T>,
    status: &Status<P>,
    clock: &Clock,
): u64 {
    let start_time = status.start_time();
    let current_time = clock.timestamp_ms();
    let raw_price = if (current_time > start_time) {
        let epoch = (current_time - start_time) / rule.period;
        rule.initial_price + epoch * rule.price_increment
    } else {
        rule.initial_price
    };
    rule.factor.mul_u64(raw_price).ceil()
}
