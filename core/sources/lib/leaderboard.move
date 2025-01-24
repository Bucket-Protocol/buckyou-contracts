module buckyou_core::leaderboard;

//***********************
//  Structs
//***********************

public struct LeaderData has copy, drop, store {
    account: address,
    shares: u64,
}

public struct Leaderboard has copy, drop, store {
    max_size: u64,
    contents: vector<LeaderData>,
}

//***********************
//  Public Funs
//***********************

public fun new(max_size: u64): Leaderboard {
    Leaderboard {
        max_size, contents: vector[],
    }
}

public fun insert(
    leaderboard: &mut Leaderboard,
    account: address,
    shares: u64,
) {
    let max_size = leaderboard.max_size;
    let contents = &mut leaderboard.contents;
    let idx = contents.find_index!(|data| data.account == account);
    if (idx.is_some()) {
        let idx = idx.destroy_some();
        contents.remove(idx);
    };
    let idx = contents.find_index!(|data| data.shares <= shares);
    if (idx.is_some()) {
        let idx = idx.destroy_some();
        contents.insert(LeaderData { account, shares }, idx);
        if (contents.length() > max_size) {
            contents.pop_back();
        };
    } else {
        if (contents.length() < max_size) {
            contents.push_back(LeaderData { account, shares });
        };
    };
}

//***********************
//  Getter Tests
//***********************

public fun max_size(leaderboard: &Leaderboard): u64 {
    leaderboard.max_size
}

public fun contents(leaderboard: &Leaderboard): &vector<LeaderData> {
    &leaderboard.contents
}

public fun data(data: &LeaderData): (address, u64) {
    (data.account, data.shares)
}

//***********************
//  Unit Tests
//***********************

#[test]
fun test_leaderboard() {
    use sui::address::from_u256;
    let max_size = 10;
    let mut leaderboard = new(max_size);
    assert!(leaderboard.max_size() == max_size);
    
    let total_count = 100_u64;
    total_count.do!(|idx| {
        let account = from_u256((idx + 1) as u256);
        let shares = 2 * (idx + 1);
        leaderboard.insert(account, shares);
    });
    // std::debug::print(&leaderboard);
    assert!(leaderboard.contents().length() == max_size);
    let (leader, shares) = leaderboard.contents()[0].data();
    assert!(leader == from_u256(100));
    assert!(shares == 200);

    total_count.do!(|idx| {
        let account = from_u256((idx + 1) as u256);
        let shares = 1000 - idx;
        leaderboard.insert(account, shares);
    });

    // std::debug::print(&leaderboard);
    assert!(leaderboard.contents().length() == max_size);
    let (leader, shares) = leaderboard.contents()[0].data();
    assert!(leader == from_u256(1));
    assert!(shares == 1000);
}