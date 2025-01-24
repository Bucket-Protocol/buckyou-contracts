module buckyou_core::pool_state;

//***********************
//  Dependencies
//***********************

use liquidlogic_framework::double::{Float};

//***********************
//  Structs
//***********************

public struct PoolState has store, copy, drop {
    pool_id: ID,
    unit: Float,
}

//***********************
//  Package Funs
//***********************

public(package) fun new(
    pool_id: ID,
    unit: Float,
): PoolState {
    PoolState { pool_id, unit }
}

public(package) fun add_unit(
    state: &mut PoolState,
    increment: Float,
) {
    state.unit = state.unit().add(increment);
}

//***********************
//  Getter Funs
//***********************

public fun pool_id(state: &PoolState): ID {
    state.pool_id
}

public fun unit(state: &PoolState): Float {
    state.unit
}

//***********************
//  Unit Tests
//***********************

#[test]
fun test_pool_state() {
    use liquidlogic_framework::double;
    let pool_id = @123.to_id();

    let mut pool_state = new(pool_id, double::from(0));
    assert!(pool_state.pool_id() == pool_id);
    assert!(pool_state.unit() == double::from(0));

    pool_state.add_unit(double::from_fraction(1, 100));
    assert!(pool_state.pool_id() == pool_id);
    assert!(pool_state.unit() == double::from_percent(1));

    pool_state.add_unit(double::from_fraction(3, 1000));
    assert!(pool_state.pool_id() == pool_id);
    assert!(pool_state.unit() == double::from_bps(130));
}
