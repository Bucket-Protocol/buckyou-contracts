module cny_2025::cny_2025;

use sui::sui::SUI;
use liquidlogic_framework::float;
use buckyou_core::admin;
use buckyou_core::config;
use buckyou_core::status;
use buckyou_core::pool;
use buckyou_core::step_price::{Self, STEP_PRICE_RULE};
use cny_2025::buck::{BUCK};
use cny_2025::but::{BUT};

public fun period(): u64 { 86400_000 }
public fun sui_price_step(): u64 { 1_000_000_000 }
public fun buck_price_step(): u64 { 4_000_000_000 }
public fun but_price_step(): u64 { 150_000_000_000 }

// otw
public struct CNY_2025 has drop {}

// init
#[allow(lint(share_owned))]
fun init(otw: CNY_2025, ctx: &mut TxContext) {
    let mut cap = admin::new(otw, ctx);
    // create config
    let config = config::new(
        &mut cap,
        float::from_percent(35),
        float::from_percent(45),
        float::from_percent(10),
        vector[10, 20, 30, 40].map!(|percent| float::from_percent(percent)),
        10,
        float::from_percent(90),
        period(),
        60_000,
        period(),
        ctx,
    );
    transfer::public_share_object(config);
    
    // create status
    let (mut status, starter) = status::new(&mut cap, 10, ctx);
    
    // create sui pool and price rule
    let mut pool = pool::new<CNY_2025, SUI>(&cap, &mut status, ctx);
    let price_rule = step_price::new<CNY_2025, SUI>(
        &cap,
        sui_price_step(),
        period(),
        sui_price_step(),
        float::from(1),
        ctx,
    );
    pool.add_rule<CNY_2025, SUI, STEP_PRICE_RULE>(&cap);
    transfer::public_share_object(price_rule);
    transfer::public_share_object(pool);

    // create buck pool and price rule
    let mut pool = pool::new<CNY_2025, BUCK>(&cap, &mut status, ctx);
    let price_rule = step_price::new<CNY_2025, BUCK>(
        &cap,
        buck_price_step(),
        period(),
        buck_price_step(),
        float::from(1),
        ctx,
    );
    pool.add_rule<CNY_2025, BUCK, STEP_PRICE_RULE>(&cap);
    transfer::public_share_object(price_rule);
    transfer::public_share_object(pool);

    // create but pool and price rule
    let mut pool = pool::new<CNY_2025, BUT>(&cap, &mut status, ctx);
    let price_rule = step_price::new<CNY_2025, BUT>(
        &cap,
        but_price_step(),
        period(),
        but_price_step(),
        float::from(1),
        ctx,
    );
    pool.add_rule<CNY_2025, BUT, STEP_PRICE_RULE>(&cap);
    transfer::public_share_object(price_rule);
    transfer::public_share_object(pool);

    transfer::public_share_object(status);
    transfer::public_transfer(cap, ctx.sender());
    transfer::public_transfer(starter, ctx.sender());
}