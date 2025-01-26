#[test_only]
module buckyou_core::test_utils;

use sui::test_scenario::{Self as ts, Scenario};
use sui::clock::{Self, Clock};
use sui::sui::SUI;
use sui::coin;
use liquidlogic_framework::float::{Self, Float};
use liquidlogic_framework::account;
use buckyou_core::admin::{Self, AdminCap};
use buckyou_core::config::{Self, Config};
use buckyou_core::status::{Self, Status};
use buckyou_core::pool::{Self, Pool};
use buckyou_core::entry;
use buckyou_core::step_price::{Self, Rule, STEP_PRICE_RULE};

// config
public fun admin(): address { @0xde }
public fun final_ratio(): Float { float::from_percent(35) }
public fun holders_ratio(): Float { float::from_percent(45) }
public fun referrer_ratio(): Float { float::from_percent(10) }
public fun winner_distribution(): vector<Float> { vector[10, 20, 30, 40].map!(|percent| float::from_percent(percent) ) }
public fun referral_threshold(): u64 { 10 }
public fun referral_factor(): Float { float::from_percent(90) }
public fun minutes(m: u64): u64 { m * 60_000 }
public fun days(d: u64): u64 { d * 86400_000 }
public fun initial_countdown(): u64 { days(1) } // one day
public fun time_increment(): u64 { minutes(1) } // one minute
public fun end_time_hard_cap(): u64 { days(1) } // one day
public fun start_time(): u64 { 1737892800000 }
public fun current_time(): u64 { start_time() - days(1) }

// price
public fun initial_price(): u64 { 1_000_000_000 }
public fun price_period(): u64 { 86400_000 }
public fun price_increment(): u64 { 1_000_000_000 }
public fun price_factor(): Float { float::from(1) }

//***********************
//  Public Funs
//***********************

public fun setup<P: drop>(): Scenario {
    let mut scenario = ts::begin(admin());
    let s = &mut scenario;

    s.next_tx(admin());
    let mut cap = admin::new_for_testing<P>(s.ctx());
    let config = config::new(
        &mut cap,
        final_ratio(),
        holders_ratio(),
        referrer_ratio(),
        winner_distribution(),
        referral_threshold(),
        referral_factor(),
        initial_countdown(),
        time_increment(),
        end_time_hard_cap(),
        s.ctx(),
    );

    let (mut status, starter) = status::new(&mut cap, 10, s.ctx());
    status.start(&config, starter, start_time());

    assert!(*cap.config_id().borrow() == object::id(&config));
    assert!(*cap.status_id().borrow() == object::id(&status));
    assert!(status.end_time() == start_time() + config.initial_countdown());

    let mut pool = pool::new<P, SUI>(&cap, &mut status, s.ctx());
    let sui_price_rule = step_price::new<P, SUI>(
        &cap, initial_price(), price_period(), price_increment(), price_factor(), s.ctx()
    );
    pool.add_rule<P, SUI, STEP_PRICE_RULE>(&cap);

    transfer::public_share_object(sui_price_rule);
    transfer::public_share_object(config);
    transfer::public_share_object(status);
    transfer::public_share_object(pool);
    transfer::public_transfer(cap, admin());

    // create clock
    let mut clock = clock::create_for_testing(s.ctx());
    clock.set_for_testing(current_time());
    clock.share_for_testing();

    scenario
}

public fun add_pool<P, T>(
    s: &mut Scenario,
    initial_price: u64,
    price_period: u64,
    price_increment: u64,
    price_factor: Float,
) {
    s.next_tx(admin());

    let cap = s.take_from_sender<AdminCap<P>>();
    let mut status = s.take_shared<Status<P>>();

    let mut pool = pool::new<P, T>(&cap, &mut status, s.ctx());
    let price_rule = step_price::new<P, T>(
        &cap, initial_price, price_period, price_increment, price_factor, s.ctx()
    );
    transfer::public_share_object(price_rule);
    pool.add_rule<P, T, STEP_PRICE_RULE>(&cap);
    transfer::public_share_object(pool);

    s.return_to_sender(cap);
    ts::return_shared(status);
}

public fun time_pass(
    s: &mut Scenario,
    tick: u64,
) {
    s.next_tx(admin());
    let mut clock = s.take_shared<Clock>();
    clock.increment_for_testing(tick);
    ts::return_shared(clock);
}

public fun buy<P, T>(
    s: &mut Scenario,
    account: address,
    ticket_count: u64,
    payment_amount: Option<u64>,
    referrer: Option<address>,
) {
    s.next_tx(account);
    let config = s.take_shared<Config<P>>();
    let mut status = s.take_shared<Status<P>>();
    let mut pool = s.take_shared<Pool<P, T>>();
    let rule = s.take_shared<Rule<P, T>>();
    let clock = s.take_shared<Clock>();

    rule.update_price(&status, &mut pool, &clock);
    let req = account::request(s.ctx());
    let payment_amount = payment_amount.destroy_or!(ticket_count * pool.price(&clock));
    let mut coin = coin::mint_for_testing<T>(payment_amount, s.ctx());
    entry::buy(&config, &mut status, &mut pool, &clock, req, ticket_count, &mut coin, referrer);
    coin.burn_for_testing();

    ts::return_shared(config);
    ts::return_shared(status);
    ts::return_shared(pool);
    ts::return_shared(rule);
    ts::return_shared(clock);
}

public fun rebuy<P, T>(
    s: &mut Scenario,
    account: address,
    ticket_count: u64,
    referrer: Option<address>,
) {
    s.next_tx(account);
    let config = s.take_shared<Config<P>>();
    let mut status = s.take_shared<Status<P>>();
    let mut pool = s.take_shared<Pool<P, T>>();
    let rule = s.take_shared<Rule<P, T>>();
    let clock = s.take_shared<Clock>();

    rule.update_price(&status, &mut pool, &clock);
    let req = account::request(s.ctx());
    entry::rebuy(&config, &mut status, &mut pool, &clock, req, ticket_count, referrer);

    ts::return_shared(config);
    ts::return_shared(status);
    ts::return_shared(pool);
    ts::return_shared(rule);
    ts::return_shared(clock);
}

public fun redeem<P, V: key + store>(
    s: &mut Scenario,
    account: address,
    count: u64,
) {
    s.next_tx(account);

    let config = s.take_shared<Config<P>>();
    let mut status = s.take_shared<Status<P>>();
    let clock = s.take_shared<Clock>();

    count.do!(|_| {
        let req = account::request(s.ctx());
        let voucher = s.take_from_sender<V>();
        entry::redeem(&config, &mut status, &clock, req, voucher);
    });

    ts::return_shared(config);
    ts::return_shared(status);
    ts::return_shared(clock);
}

public fun add_referrer<P>(
    s: &mut Scenario,
    referrer: address,
) {
    s.next_tx(admin());
    let mut status = s.take_shared<Status<P>>();
    let cap = s.take_from_sender<AdminCap<P>>();

    status.add_referrer(&cap, referrer);

    ts::return_shared(status);
    s.return_to_sender(cap);
}

public fun add_voucher_type<P, V>(s: &mut Scenario) {
    s.next_tx(admin());
    let mut status = s.take_shared<Status<P>>();
    let cap = s.take_from_sender<AdminCap<P>>();

    status.add_voucher_type<P, V>(&cap);

    ts::return_shared(status);
    s.return_to_sender(cap);
}

public fun settle_winners<P, T>(s: &mut Scenario) {
    s.next_tx(admin());
    let mut pool = s.take_shared<Pool<P, T>>();
    let config = s.take_shared<Config<P>>();
    let mut status = s.take_shared<Status<P>>();
    let clock = s.take_shared<Clock>();

    pool.settle_winners(&config, &mut status, &clock, s.ctx());

    ts::return_shared(pool);
    ts::return_shared(config);
    ts::return_shared(status);
    ts::return_shared(clock);
}
