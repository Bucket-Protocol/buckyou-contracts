#[test_only]
module buckyou_core::test_buy_failure;

use sui::sui::SUI;
use sui::test_scenario::{Self as ts};
use buckyou_core::admin::{AdminCap};
use buckyou_core::entry;
use buckyou_core::status;
use buckyou_core::version;
use buckyou_core::config::{Self, Config};
use buckyou_core::test_utils::{Self as tu};
use buckyou_core::test_project::{TEST_PROJECT};

#[test, expected_failure(abort_code = entry::EBuyNothing)]
fun test_buy_nothing() {
    let mut scenario = tu::setup<TEST_PROJECT>();
    let s = &mut scenario;

    tu::time_pass(s, tu::days(1) + tu::minutes(1));

    let user = @0xb0b;
    tu::buy<TEST_PROJECT, SUI>(s, user, 0, option::none(), option::none());

    scenario.end();
}

#[test, expected_failure(abort_code = entry::EPaymentNotEnough)]
fun test_payment_not_enough() {
    let mut scenario = tu::setup<TEST_PROJECT>();
    let s = &mut scenario;

    tu::time_pass(s, tu::days(1) + tu::minutes(1));

    let user = @0xb0b;
    tu::buy<TEST_PROJECT, SUI>(s, user, 10, option::some(9_999_999_999), option::none());

    scenario.end();
}

#[test, expected_failure(abort_code = status::EGameIsNotStarted)]
fun test_buy_before_start() {
    let mut scenario = tu::setup<TEST_PROJECT>();
    let s = &mut scenario;

    tu::time_pass(s, tu::days(1) - tu::minutes(1));

    let user = @0xb0b;
    tu::buy<TEST_PROJECT, SUI>(s, user, 1, option::none(), option::none());

    scenario.end();
}

#[test, expected_failure(abort_code = status::EGameIsEnded)]
fun test_buy_after_end() {
    let mut scenario = tu::setup<TEST_PROJECT>();
    let s = &mut scenario;

    tu::time_pass(s, tu::days(2) + tu::minutes(1));

    let user = @0xb0b;
    tu::buy<TEST_PROJECT, SUI>(s, user, 1, option::none(), option::none());

    scenario.end();
}

#[test, expected_failure(abort_code = config::EInvalidPackageVersion)]
fun test_buy_with_invalid_package() {
    let mut scenario = tu::setup<TEST_PROJECT>();
    let s = &mut scenario;

    s.next_tx(tu::admin());
    let mut config = s.take_shared<Config<TEST_PROJECT>>();
    let cap = s.take_from_sender<AdminCap<TEST_PROJECT>>();
    let current_package = version::package_version();
    config.add_version(&cap, current_package + 1);
    config.remove_version(&cap, current_package);
    ts::return_shared(config);
    s.return_to_sender(cap);

    tu::time_pass(s, tu::days(1) + tu::minutes(1));

    let user = @0xb0b;
    tu::buy<TEST_PROJECT, SUI>(s, user, 1, option::none(), option::none());
    
    scenario.end();
}