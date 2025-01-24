module buckyou_core::pool;

//***********************
//  Dependencies
//***********************

use std::type_name::{get, TypeName};
use sui::balance::{Self, Balance};
use sui::vec_set::{Self, VecSet};
use sui::clock::{Clock};
use sui::coin::{Coin};
use sui::event::{emit};
use liquidlogic_framework::account::{AccountRequest};
use buckyou_core::admin::{AdminCap};
use buckyou_core::config::{Config};
use buckyou_core::status::{Status};

//***********************
//  Errors
//***********************

const EInvalidUpdatePriceRule: u64 = 0;
fun err_invalid_update_price_rule() { abort EInvalidUpdatePriceRule }

const EPriceFeedOutdated: u64 = 1;
fun err_price_feed_outdated() { abort EPriceFeedOutdated }

const EAccountNotFound: u64 = 2;
fun err_account_not_found() { abort EAccountNotFound }

//***********************
//  Events
//***********************

public struct PoolBalances<phantom P, phantom T> has copy, drop {
    pool_id: ID,
    final_balance: u64,
    holders_balance: u64,
    dev_balance: u64,
}

public struct FinalWinners<phantom P, phantom T> has copy, drop {
    pool_id: ID,
    winners: vector<address>,
    prizes: vector<u64>,
}

//***********************
//  Object
//***********************

public struct Pool<phantom P, phantom T> has key, store {
    id: UID,
    price: u64,
    timestamp: u64,
    rules: VecSet<TypeName>,
    // balances
    final_balance: Balance<T>,
    holders_balance: Balance<T>,
    dev_balance: Balance<T>,
}

//***********************
//  Admin Funs
//***********************

public fun new<P, T>(
    _cap: &AdminCap<P>,
    status: &mut Status<P>,
    ctx: &mut TxContext,
): Pool<P, T> {
    let coin_type = get<T>();
    let pool = Pool<P, T> {
        id: object::new(ctx),
        price: 0,
        timestamp: 0,
        rules: vec_set::empty(),
        // balances
        final_balance: balance::zero(),
        holders_balance: balance::zero(),
        dev_balance: balance::zero(),
    };
    let pool_id = object::id(&pool);
    status.add_pool(coin_type, pool_id);
    pool.emit_pool_balances();
    pool
}

public fun add_rule<P, T, R>(
    pool: &mut Pool<P, T>,
    _cap: &AdminCap<P>,
) {
    let rule_name = get<R>();
    if (!pool.rules.contains(&rule_name)) {
        pool.rules.insert(rule_name);
    };
}

public fun remove_rule<P, T, R>(
    pool: &mut Pool<P, T>,
    _cap: &AdminCap<P>,
) {
    let rule_name = get<R>();
    if (pool.rules.contains(&rule_name)) {
        pool.rules.remove(&rule_name);
    };
}

public fun dev_claim<P, T>(
    pool: &mut Pool<P, T>,
    _cap: &AdminCap<P>,
    ctx: &mut TxContext,
): Coin<T> {
    let coin = pool.dev_balance.withdraw_all().into_coin(ctx);
    pool.emit_pool_balances();
    coin
}

entry fun dev_claim_to<P, T>(
    pool: &mut Pool<P, T>,
    cap: &AdminCap<P>,
    recipient: address,
    ctx: &mut TxContext,
) {
    let coin = pool.dev_claim(cap, ctx);
    transfer::public_transfer(coin, recipient);
}

//***********************
//  Public Funs
//***********************

public fun supply<P, T>(
    pool: &mut Pool<P, T>,
    coin: Coin<T>,
) {
    pool.final_balance.join(coin.into_balance());
    pool.emit_pool_balances();
}

public fun update_price<P, T, R: drop>(
    pool: &mut Pool<P, T>,
    clock: &Clock,
    _rule: R,
    price: u64,
) {
    let rule_name = get<R>();
    if (!pool.rules.contains(&rule_name)) {
        err_invalid_update_price_rule();
    };
    pool.price = price;
    pool.timestamp = clock.timestamp_ms();
}

public fun settle_winners<P, T>(
    pool: &mut Pool<P, T>,
    config: &Config<P>,
    status: &mut Status<P>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // check version
    config.assert_valid_package_version();

    // check game is ended
    status.assert_game_is_ended(clock);

    // distribute
    let final_pool_size = pool.final_balance.value();
    let mut prizes = vector[];
    status.winners().zip_do_ref!(config.winner_distribution(), |winner, ratio| {
        let prize_amount = (*ratio).mul_u64(final_pool_size).floor();
        prizes.push_back(prize_amount);
        let prize = pool.final_balance.split(prize_amount).into_coin(ctx);
        transfer::public_transfer(prize, *winner);
    });
    pool.emit_pool_balances();
    emit(FinalWinners<P, T> {
        pool_id: object::id(pool),
        winners: *status.winners(),
        prizes,
    });
}

public fun claim_all<P, T>(
    pool: &mut Pool<P, T>,
    config: &Config<P>,
    status: &mut Status<P>,
    clock: &Clock,
    req: AccountRequest,
    ctx: &mut TxContext,
): Coin<T> {
    // can only claim after game is ended
    status.assert_game_is_ended(clock);

    let account = req.destroy();
    let coin_type = get<T>();
    let total_reward = status.user_profiles().borrow(account).states().get(&coin_type).total_reward();
    pool.claim(config, status, account, total_reward).into_coin(ctx)
}

//***********************
//  Package Funs
//***********************

public(package) fun deposit<P, T>(
    pool: &mut Pool<P, T>,
    for_final: Balance<T>,
    for_holders: Balance<T>,
    for_dev: Balance<T>,
) {
    pool.final_balance.join(for_final);
    pool.holders_balance.join(for_holders);
    pool.dev_balance.join(for_dev);
    pool.emit_pool_balances();
}

public(package) fun claim<P, T>(
    pool: &mut Pool<P, T>,
    config: &Config<P>,
    status: &mut Status<P>,
    account: address,
    amount: u64,
): Balance<T> {
    // check version
    config.assert_valid_package_version();

    // update user state
    status.update_user_state(account, option::none());
    if (!status.user_profiles().contains(account)) {
        err_account_not_found();
    };
    let coin_type = get<T>();
    let user_state = status.user_profiles_mut().borrow_mut(account).states_mut().get_mut(&coin_type);
    user_state.claim(amount);
    let out = pool.holders_balance.split(amount);
    pool.emit_pool_balances();
    out
}

//***********************
//  Getter Funs
//***********************

public fun price<P, T>(
    pool: &Pool<P, T>,
    clock: &Clock,
): u64 {
    if (pool.timestamp != clock.timestamp_ms()) {
        err_price_feed_outdated();
    };
    pool.price
}

//***********************
//  Internal Funs
//***********************

fun emit_pool_balances<P, T>(pool: &Pool<P, T>) {
    emit(PoolBalances<P, T> {
        pool_id: object::id(pool),
        final_balance: pool.final_balance.value(),
        holders_balance: pool.holders_balance.value(),
        dev_balance: pool.dev_balance.value(),
    });
}