module buckyou_core::status;

//***********************
//  Dependencies
//***********************

use std::ascii::{String};
use std::type_name::{get, TypeName};
use sui::clock::{Self, Clock};
use sui::event::{emit};
use sui::vec_map::{Self, VecMap};
use sui::table::{Self, Table};
use sui::vec_set::{Self, VecSet};
use liquidlogic_framework::double;
use buckyou_core::config::{Config};
use buckyou_core::admin::{AdminCap};
use buckyou_core::profile::{Self, Profile};
use buckyou_core::pool_state::{Self, PoolState};
use buckyou_core::user_state;
use buckyou_core::leaderboard::{Self, Leaderboard};

//***********************
//  Errors
//***********************

const EGameIsNotStarted: u64 = 1;
fun err_game_is_not_started() { abort EGameIsNotStarted }

const EGameIsNotEnded: u64 = 2;
fun err_game_is_not_ended() { abort EGameIsNotEnded }

const EGameIsEnded: u64 = 3;
fun err_game_is_ended() { abort EGameIsEnded }

const EPoolAlreadyCreated: u64 = 4;
fun err_pool_already_created() { abort EPoolAlreadyCreated }

const EInvalidReferrer: u64 = 5;
fun err_invalid_referrer() { abort EInvalidReferrer }

const ESelfRefer: u64 = 6;
fun err_self_refer() { abort ESelfRefer }

//***********************
//  Events
//***********************

public struct NewEndTime<phantom P> has copy, drop {
    ms: u64,
}

public struct Refer<phantom P> has copy, drop {
    referrer: address,
    refered: address,
}

public struct AddShares<phantom P> has copy, drop {
    coin_type: String,
    shares: u64,
    total_shares: u64,
}

public struct Earn<phantom P> has copy, drop {
    account: address,
    coin_type: String,
    amount: u64,
    from_holders: bool,
}

//***********************
//  Objects
//***********************

public struct Status<phantom P> has key, store {
    id: UID,
    start_time: u64,
    end_time: u64,
    winners: vector<address>,
    // global
    total_shares: u64,
    pool_states: VecMap<TypeName, PoolState>,
    referral_whitelist: VecSet<address>,
    voucher_whitelist: VecSet<TypeName>,
    // users
    user_profiles: Table<address, Profile>,
    leaderboard: Leaderboard,
}

public struct Starter<phantom P> has key, store {
    id: UID,
}

//***********************
//  Public Funs
//***********************   

public fun new<P>(
    cap: &mut AdminCap<P>,
    leaderboard_size: u64,
    ctx: &mut TxContext,
): (Status<P>, Starter<P>) {
    let status = Status<P> {
        id: object::new(ctx),
        start_time: max_u64(),
        end_time: max_u64(),
        winners: vector[],
        // global
        total_shares: 0,
        pool_states: vec_map::empty(),
        referral_whitelist: vec_set::empty(),
        voucher_whitelist: vec_set::empty(),
        // users
        user_profiles: table::new(ctx),
        leaderboard: leaderboard::new(leaderboard_size),
    };
    cap.set_status_id(object::id(&status));
    let starter = Starter<P> { id: object::new(ctx) };
    (status, starter)
}

public fun start<P>(
    status: &mut Status<P>,
    config: &Config<P>,
    starter: Starter<P>,
    start_time: u64,
) {
    let Starter { id } = starter;
    object::delete(id);

    status.start_time = start_time;
    status.end_time = start_time + config.initial_countdown();
    emit(NewEndTime<P> { ms: status.end_time() });
}

//***********************
//  Package Funs
//***********************

public(package) fun add_pool<P>(
    status: &mut Status<P>,
    coin_type: TypeName,
    pool_id: ID,
) {
    if (status.pool_states().contains(&coin_type)) {
        err_pool_already_created();
    };
    status.pool_states.insert(
        coin_type,
        pool_state::new(pool_id, double::from(0))
    );
}

public(package) fun handle_final<P>(
    status: &mut Status<P>,
    config: &Config<P>,
    clock: &Clock,
    account: address,
    ticket_count: u64,
) {
    // add account to winners
    let max_winner_count = config.max_winner_count();
    ticket_count.min(max_winner_count).do!(|_| {
        if (status.winners.length() == max_winner_count) {
            status.winners.remove(0);
        };
        status.winners.push_back(account);
    });

    // increase end time and check hard cap
    let current_time = clock::timestamp_ms(clock);
    let mut new_end_time = status.end_time + ticket_count * config.time_increment();
    let end_time_hard_cap = config.end_time_hard_cap();
    if (new_end_time > current_time + end_time_hard_cap) {
        new_end_time = current_time + end_time_hard_cap;
    };
    if (status.end_time < new_end_time) {
        status.end_time = new_end_time;
        emit(NewEndTime<P> { ms: new_end_time });
    };
}

public(package) fun handle_referrer<P, T>(
    status: &mut Status<P>,
    config: &Config<P>,
    account: address,
    referrer: Option<address>,
    amount_for_referrer: u64,
): Option<address> {
    status.update_user_state(account, referrer);
    let referrer = status.user_profiles().borrow(account).referrer();
    if (referrer.is_some()) {
        let referrer = referrer.destroy_some();
        if (!status.is_valid_referrer(config, referrer)) {
            err_invalid_referrer();
        };
        if (referrer == account) {
            err_self_refer();
        };
        status.update_user_state(referrer, option::none());
        if (amount_for_referrer > 0) {
            let coin_type = get<T>();
            status
                .user_profiles
                .borrow_mut(referrer)
                .states_mut()
                .get_mut(&coin_type)
                .rebate(amount_for_referrer);
            emit(Earn<P> {
                account: referrer,
                amount: amount_for_referrer,
                coin_type: coin_type.into_string(),
                from_holders: false,
            });
        };
    };
    referrer
}

public(package) fun handle_holders<P, T>(
    status: &mut Status<P>,
    account: address,
    ticket_count: u64,
    reward_for_holders: u64,
) {
    let coin_type = get<T>();
    status.total_shares = status.total_shares() + ticket_count;
    status.user_profiles.borrow_mut(account).add_shares(ticket_count);
    let increment = double::from_fraction(reward_for_holders, status.total_shares());
    status.pool_states.get_mut(&coin_type).add_unit(increment);
    emit(AddShares<P> {
        coin_type: coin_type.into_string(),
        shares: ticket_count,
        total_shares: status.total_shares(),
    });
}

public(package) fun user_profiles_mut<P>(status: &mut Status<P>): &mut Table<address, Profile> {
    &mut status.user_profiles
}

//***********************
//  Getter Functions
//***********************

public fun max_u64(): u64 { 0xffffffffffffffff }

public fun assert_game_is_started<P>(
    status: &Status<P>,
    clock: &Clock,
) {
    let current_time = clock::timestamp_ms(clock);
    if (current_time < status.start_time) {
        err_game_is_not_started();
    };
}

public fun assert_game_is_ended<P>(
    status: &Status<P>,
    clock: &Clock,
) {
    let current_time = clock::timestamp_ms(clock);
    if (current_time <= status.end_time) {
        err_game_is_not_ended();
    };
}

public fun assert_game_is_not_ended<P>(
    status: &Status<P>,
    clock: &Clock,
) {
    let current_time = clock::timestamp_ms(clock);
    if (current_time > status.end_time) {
        err_game_is_ended();
    };
}

public fun start_time<P>(status: &Status<P>): u64 {
    status.start_time
}

public fun end_time<P>(status: &Status<P>): u64 {
    status.end_time
}

public fun winners<P>(status: &Status<P>): &vector<address> {
    &status.winners
}

public fun total_shares<P>(status: &Status<P>): u64 {
    status.total_shares
}

public fun pool_states<P>(status: &Status<P>): &VecMap<TypeName, PoolState> {
    &status.pool_states
}

public fun user_profiles<P>(status: &Status<P>): &Table<address, Profile> {
    &status.user_profiles
}

public fun leaderboard<P>(status: &Status<P>): &Leaderboard {
    &status.leaderboard
}

public fun is_valid_referrer<P>(
    status: &Status<P>,
    config: &Config<P>,
    referrer: address,
): bool {
    status.referral_whitelist.contains(&referrer) || 
    {
        status.user_profiles().contains(referrer) &&
        status.user_profiles().borrow(referrer).shares() >= config.referral_threshold()
    }
}

public fun pending_holders_reward<P>(
    status: &Status<P>,
    account: address,
    coin_type: &TypeName,
): u64 {
    if (
        status.pool_states().contains(coin_type) &&
        status.user_profiles().contains(account)
    ) {
        let pool_unit = status.pool_states().get(coin_type).unit();
        let profile = status.user_profiles().borrow(account);
        let user_unit = if (profile.states().contains(coin_type)) {
            profile.states().get(coin_type).unit()
        } else {
            double::from(0)
        };
        pool_unit.sub(user_unit).mul_u64(profile.shares()).floor()
    } else {
        0
    }
}

public fun realtime_holders_reward<P>(
    status: &Status<P>,
    account: address,
    coin_type: &TypeName,
): u64 {
    status.pending_holders_reward<P>(account, coin_type) +
    if (status.user_profiles().contains(account) &&
        status.user_profiles().borrow(account).states().contains(coin_type)
    ) {
        status.user_profiles().borrow(account).states().get(coin_type).holders_reward()
    } else {
        0
    }
}

public fun realtime_referral_reward<P>(
    status: &Status<P>,
    account: address,
    coin_type: &TypeName,
): u64 {
    if (status.user_profiles().contains(account) &&
        status.user_profiles().borrow(account).states().contains(coin_type)
    ) {
        status.user_profiles().borrow(account).states().get(coin_type).referral_reward()
    } else {
        0
    }
}

//***********************
//  Internal Funs
//***********************

public(package) fun update_user_state<P>(
    status: &mut Status<P>,
    account: address,
    referrer: Option<address>,
) {
    if (!status.user_profiles().contains(account)) {
        let mut profile = profile::new(referrer);
        status.pool_states().keys().do!(|coin_type| {
            let pool_unit = status.pool_states().get(&coin_type).unit();
            profile.states_mut().insert(coin_type, user_state::new(pool_unit));
        });
    } else {
        let all_coin_types = status.pool_states().keys();
        all_coin_types.do!(|coin_type| {
            let pool_unit = status.pool_states.get(&coin_type).unit();
            let profile = status.user_profiles.borrow_mut(account);
            let shares = profile.shares();
            if (profile.states().contains(&coin_type)) {
                let user_state = profile.states_mut().get_mut(&coin_type);
                let user_unit = user_state.unit();
                let pending_reward = pool_unit.sub(user_unit).mul_u64(shares).floor();
                user_state.settle(pending_reward);
                emit(Earn<P> {
                    account,
                    amount: pending_reward,
                    coin_type: coin_type.into_string(),
                    from_holders: true,
                });
                user_state.set_unit(pool_unit);
            } else {
                let user_state = if (shares > 0) {
                    let pending_reward = pool_unit.mul_u64(shares).floor();
                    let mut user_state = user_state::new(pool_unit);
                    user_state.settle(pending_reward);
                    emit(Earn<P> {
                        account,
                        amount: pending_reward,
                        coin_type: coin_type.into_string(),
                        from_holders: true,
                    });
                    user_state
                } else {
                    user_state::new(pool_unit)
                };
                profile.states_mut().insert(coin_type, user_state);            
            };
        });
        let profile = status.user_profiles.borrow_mut(account);
        if (referrer.is_some() && profile.referrer().is_none()) {
            let referrer = referrer.destroy_some();
            profile.set_referrer(referrer);
            status.user_profiles.borrow_mut(referrer).add_score();
            emit(Refer<P> { referrer, refered: account});
        };
    }
}

//***********************
//  Display Funs
//***********************

public struct AccountInfo has copy, drop {
    coin_types: vector<String>,
    holders_rewards: vector<u64>,
    referral_rewards: vector<u64>,
    shares: u64,
}

public fun get_account_info<P>(
    status: &Status<P>,
    account: address,
): Option<AccountInfo> {
    if (status.user_profiles().contains(account)) {
        let coin_types = status.pool_states().keys();
        let holders_rewards = coin_types.map_ref!(|coin_type| {
            status.realtime_holders_reward(account, coin_type)
        });
        let referral_rewards = coin_types.map_ref!(|coin_type| {
            status.realtime_referral_reward(account, coin_type)            
        });
        let shares = status.user_profiles().borrow(account).shares();
        let coin_types = coin_types.map!(|coin_type| coin_type.into_string());
        option::some(AccountInfo {
            coin_types, holders_rewards, referral_rewards, shares,
        })
    } else {
        option::none()
    }
}

//***********************
//  Testnet-only Funs
//***********************

public fun extend_end_time<P>(
    status: &mut Status<P>,
    _cap: &AdminCap<P>,
    end_time: u64,
) {
    status.end_time = end_time;
}
