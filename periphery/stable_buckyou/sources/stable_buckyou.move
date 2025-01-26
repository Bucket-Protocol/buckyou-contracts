module stable_buckyou::stable_buckyou;

use sui::clock::{Clock};
use sui::coin::{Coin};
use liquidlogic_framework::account::{AccountRequest};
use bucket_protocol::buck::{BUCK, BucketProtocol};
use buckyou_core::config::{Config};
use buckyou_core::status::{Status};
use buckyou_core::pool::{Pool};
use buckyou_core::entry;

// Errors
const EPaymentNotEnough: u64 = 0;
fun err_payment_not_enough() { abort EPaymentNotEnough }

// witness
public struct StableBuckyou<phantom P> has drop {}

public fun buy<P, U>(
    config: &Config<P>,
    status: &mut Status<P>,
    pool: &mut Pool<P, BUCK>,
    clock: &Clock,
    req0: AccountRequest,
    ticket_count: u64,
    coin: &mut Coin<U>,
    referrer: Option<address>,
    protocol: &mut BucketProtocol,
    req1: AccountRequest,
    ctx: &mut TxContext,
): Coin<BUCK> {
    let mut payment_amount = ticket_count * pool.price(clock);
    let account = req0.destroy();
    if (status.try_get_referrer(account).is_some() || referrer.is_some()) {
        payment_amount = config.referral_factor().mul_u64(payment_amount).ceil();
    };
    let u_amount = payment_amount / 1000;
    if (coin.value() < u_amount) {
        err_payment_not_enough();
    };
    let u_balance = coin.balance_mut().split(u_amount);
    let buck_balance = protocol.charge_reservoir_by_partner(u_balance, StableBuckyou<P> {});
    let mut buck_coin = buck_balance.into_coin(ctx);
    entry::buy(
        config,
        status,
        pool,
        clock,
        req1,
        ticket_count,
        &mut buck_coin,
        referrer,
    );
    buck_coin
}
