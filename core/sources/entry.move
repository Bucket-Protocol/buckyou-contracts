module buckyou_core::entry;

//***********************
//  Dependencies
//***********************

use std::ascii::{String};
use std::type_name::{get};
use sui::clock::{Clock};
use sui::balance::{Balance};
use sui::coin::{Coin};
use sui::event::{emit};
use liquidlogic_framework::account::{AccountRequest};
use buckyou_core::config::{Config};
use buckyou_core::status::{Status};
use buckyou_core::pool::{Pool};

//***********************
//  Errors
//***********************

const EBuyNothing: u64 = 0;
fun err_buy_nothing() { abort EBuyNothing }

const EPaymentNotEnough: u64 = 1;
fun err_payment_not_enough() { abort EPaymentNotEnough }

const EInvalidVoucher: u64 = 2;
fun err_invalid_voucher() { abort EInvalidVoucher }

//***********************
//  Events
//***********************

public struct Buy<phantom P> has copy, drop {
    account: address,
    referrer: Option<address>,
    coin_type: String,
    count: u64,
    payment: u64,
    is_rebuy: bool,
}

//***********************
//  Public Funs
//***********************

public fun buy<P, T>(
    config: &Config<P>,
    status: &mut Status<P>,
    pool: &mut Pool<P, T>,
    clock: &Clock,
    req: AccountRequest,
    ticket_count: u64,
    coin: &mut Coin<T>,
    referrer: Option<address>,
) {
    if (ticket_count == 0) {
        err_buy_nothing();
    };
    let payment_amount = ticket_count * pool.price(clock);
    if (payment_amount > coin.value()) {
        err_payment_not_enough();
    };
    
    let account = req.destroy();
    let payment = coin.balance_mut().split(payment_amount);
    buy_internal(config, status, pool, clock, account, ticket_count, payment, referrer, false);
    
}

public fun rebuy<P, T>(
    config: &Config<P>,
    status: &mut Status<P>,
    pool: &mut Pool<P, T>,
    clock: &Clock,
    req: AccountRequest,
    ticket_count: u64,
    referrer: Option<address>,
) {
    if (ticket_count == 0) {
        err_buy_nothing();
    };
    let payment_amount = ticket_count * pool.price(clock);

    let account = req.destroy();
    let payment = pool.claim(config, status, account, payment_amount);
    buy_internal(config, status, pool, clock, account, ticket_count, payment, referrer, true);
}

public fun redeem<P, V: key + store>(
    config: &Config<P>,
    status: &mut Status<P>,
    clock: &Clock,
    req: AccountRequest,
    voucher: V,
) {
    // check version
    config.assert_valid_package_version();
    
    // check time
    status.assert_game_is_started(clock);
    status.assert_game_is_not_ended(clock);
    if (!status.is_valid_voucher<P, V>()) {
        err_invalid_voucher();
    };
    
    // handle final pool
    let account = req.destroy();
    status.handle_final(config, clock, account, 1);
    status.handle_redeem<P, V>(account);
    emit(Buy<P> {
        account,
        referrer: option::none(),
        coin_type: get<V>().into_string(),
        count: 1,
        payment: 0,
        is_rebuy: false,
    });
    transfer::public_transfer(voucher, object::id(status).to_address());
}

//***********************
//  Internal Funs
//***********************

fun buy_internal<P, T>(
    config: &Config<P>,
    status: &mut Status<P>,
    pool: &mut Pool<P, T>,
    clock: &Clock,
    account: address,
    ticket_count: u64,
    mut payment: Balance<T>,
    mut referrer: Option<address>,
    is_rebuy: bool,
) {
    // check version
    config.assert_valid_package_version();
    
    // check time
    status.assert_game_is_started(clock);
    status.assert_game_is_not_ended(clock);
    
    // handle final pool
    status.handle_final(config, clock, account, ticket_count);

    // handle referrer and holders
    let curr_referrer = status.try_get_referrer(account);
    if (curr_referrer.is_some()) {
        referrer = curr_referrer;
    };
    let payment_amount = payment.value();
    let referrer = if (referrer.is_some()) {
        let amount_for_final = config.final_ratio().mul_u64(payment_amount).floor();
        let reward_for_final = payment.split(amount_for_final);

        let amount_for_holders = config.holders_ratio().mul_u64(payment_amount).floor();
        let mut reward_for_holders = payment.split(amount_for_holders);

        let amount_for_referrer = config.referrer_ratio().mul_u64(payment_amount).floor();
        let reward_for_referrer = payment.split(amount_for_referrer);
        reward_for_holders.join(reward_for_referrer);

        pool.deposit(reward_for_final, reward_for_holders, payment);

        let referrer = status.handle_referrer<P, T>(config, account, referrer, amount_for_referrer);
        status.handle_holders<P, T>(account, ticket_count, amount_for_holders);
        referrer
    } else {
        let half_referrer_ratio = config.referrer_ratio().div_u64(2);
        let amount_for_final = config.final_ratio().add(half_referrer_ratio).mul_u64(payment_amount).floor();
        let reward_for_final = payment.split(amount_for_final);

        let amount_for_holders = config.holders_ratio().add(half_referrer_ratio).mul_u64(payment_amount).floor();
        let reward_for_holders = payment.split(amount_for_holders);

        pool.deposit(reward_for_final, reward_for_holders, payment);
        let referrer = status.handle_referrer<P, T>(config, account, referrer, 0);
        status.handle_holders<P, T>(account, ticket_count, amount_for_holders);
        referrer
    };
    emit(Buy<P> {
        account,
        referrer,
        coin_type: get<T>().into_string(),
        count: ticket_count,
        payment: payment_amount,
        is_rebuy,
    });
}