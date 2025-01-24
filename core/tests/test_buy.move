#[test_only]
module buckyou_core::test_buy;

use sui::sui::SUI;
use sui::test_scenario::{Self as ts};
use liquidlogic_framework::float;
use buckyou_core::status::{Status};
use buckyou_core::test_utils::{Self as tu};
use buckyou_core::test_project::{TEST_PROJECT};
use buckyou_core::buck::{BUCK};

#[test]
fun test_buy() {
    let mut scenario = tu::setup<TEST_PROJECT>();
    let s = &mut scenario;
    tu::add_pool<TEST_PROJECT, BUCK>(s, 4_000_000_000, tu::days(1), 4_000_000_000, float::from(1));

    tu::time_pass(s, tu::days(1) + tu::minutes(20));

    let user_1 = @0x111;
    let ticket_count = 10;
    tu::buy<TEST_PROJECT, SUI>(s, user_1, ticket_count, option::none(), option::none());

    s.next_tx(user_1);
    let status = s.take_shared<Status<TEST_PROJECT>>();
    assert!(status.start_time() == tu::start_time());
    assert!(status.end_time() == tu::start_time() + tu::days(1) + tu::minutes(ticket_count));
    // std::debug::print(&status.get_account_info(user_1));
    ts::return_shared(status);

    tu::time_pass(s, tu::minutes(20));

    let user_2 = @0x222;
    tu::buy<TEST_PROJECT, SUI>(s, user_2, ticket_count, option::none(), option::some(user_1));

    s.next_tx(user_2);
    let status = s.take_shared<Status<TEST_PROJECT>>();
    assert!(status.start_time() == tu::start_time());
    assert!(status.end_time() == tu::start_time() + tu::days(1) + tu::minutes(ticket_count * 2));
    // std::debug::print(&status.get_account_info(user_1));
    // std::debug::print(&status.get_account_info(user_2));
    ts::return_shared(status);

    let user_3 = @0x333;
    let ticket_count = 5;
    tu::buy<TEST_PROJECT, BUCK>(s, user_3, ticket_count, option::none(), option::some(user_2));

    s.next_tx(user_3);
    let status = s.take_shared<Status<TEST_PROJECT>>();
    // std::debug::print(&status.get_account_info(user_1));
    // std::debug::print(&status.get_account_info(user_2));
    // std::debug::print(&status.get_account_info(user_3));
    ts::return_shared(status);

    tu::rebuy<TEST_PROJECT, BUCK>(s, user_2, 1, option::some(user_3));

    s.next_tx(user_3);
    let status = s.take_shared<Status<TEST_PROJECT>>();
    std::debug::print(&status.get_account_info(user_1));
    std::debug::print(&status.get_account_info(user_2));
    std::debug::print(&status.get_account_info(user_3));
    ts::return_shared(status);

    scenario.end();
}