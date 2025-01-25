#[test_only]
module buckyou_core::test_buy;

use sui::sui::SUI;
use sui::test_scenario::{Self as ts};
use liquidlogic_framework::float;
use buckyou_core::status::{Status};
use buckyou_core::test_utils::{Self as tu};
use buckyou_core::test_project::{TEST_PROJECT};
use buckyou_core::buck::{BUCK};
use buckyou_core::voucher::{Self, Voucher};

#[test]
fun test_buy() {
    let mut scenario = tu::setup<TEST_PROJECT>();
    let s = &mut scenario;
    let referral_factor = float::from_percent(90);
    tu::add_pool<TEST_PROJECT, BUCK>(
        s, 4_000_000_000, tu::days(1), 4_000_000_000, referral_factor, float::from(1)
    );

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
    // std::debug::print(&status.get_account_info(user_1));
    // std::debug::print(&status.get_account_info(user_2));
    // std::debug::print(&status.get_account_info(user_3));
    // std::debug::print(status.leaderboard());
    // std::debug::print(status.winners());
    // std::debug::print(&status);
    ts::return_shared(status);

    tu::add_voucher_type<TEST_PROJECT, Voucher>(s);

    let user_4 = @0x444;
    let voucher_count: u64 = 4;
    s.next_tx(tu::admin());
    voucher_count.do!(|_| {
        let voucher = voucher::new(s.ctx());    
        transfer::public_transfer(voucher, user_4);
    });

    tu::time_pass(s, tu::minutes(10));

    tu::redeem<TEST_PROJECT, Voucher>(s, user_4, voucher_count);

    s.next_tx(user_4);
    let status = s.take_shared<Status<TEST_PROJECT>>();
    std::debug::print(&status.get_account_info(user_1));
    std::debug::print(&status.get_account_info(user_2));
    std::debug::print(&status.get_account_info(user_3));
    std::debug::print(&status.get_account_info(user_4));
    // std::debug::print(status.leaderboard());
    // std::debug::print(status.winners());
    // std::debug::print(&status);
    ts::return_shared(status);

    tu::time_pass(s, tu::minutes(60));

    let kol = @0x601;
    tu::add_referrer<TEST_PROJECT>(s, kol);

    let user_5 = @0x555;
    tu::buy<TEST_PROJECT, BUCK>(s, user_5, 10, option::none(), option::some(kol));

    tu::time_pass(s, tu::minutes(1));

    tu::buy<TEST_PROJECT, SUI>(s, user_5, 20, option::none(), option::none());

    s.next_tx(user_5);
    let status = s.take_shared<Status<TEST_PROJECT>>();
    // std::debug::print(&status.get_account_info(user_1));
    // std::debug::print(&status.get_account_info(user_2));
    // std::debug::print(&status.get_account_info(user_3));
    // std::debug::print(&status.get_account_info(user_4));
    // std::debug::print(&status.get_account_info(user_5));
    // std::debug::print(&status.get_account_info(kol));
    // std::debug::print(status.leaderboard());
    // std::debug::print(status.winners());
    // std::debug::print(&status);
    ts::return_shared(status);

    scenario.end();
}