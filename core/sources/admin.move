module buckyou_core::admin;

//***********************
//  Dependencies
//***********************

use sui::types;

//***********************
//  Objects
//***********************

public struct AdminCap<phantom P> has key, store {
    id: UID,
    config_id: Option<ID>,
    status_id: Option<ID>,
}

//***********************
//  Errors
//***********************

const ENotOneTimeWitness: u64 = 0;
fun err_not_one_time_witness() { abort ENotOneTimeWitness }

const EConfigAlreadyCreated: u64 = 1;
fun err_config_already_created() { abort EConfigAlreadyCreated }

const EStatusAlreadyCreated: u64 = 2;
fun err_status_already_created() { abort EStatusAlreadyCreated }

//***********************
//  Public Funs
//***********************

public fun new<P: drop>(
    project: P,
    ctx: &mut TxContext,
): AdminCap<P> {
    if (!types::is_one_time_witness(&project)) {
        err_not_one_time_witness();
    };
    AdminCap<P> {
        id: object::new(ctx),
        config_id: option::none(),
        status_id: option::none(),
    }
}

//***********************
//  Package Funs
//***********************

public(package) fun set_config_id<P>(
    cap: &mut AdminCap<P>,
    config_id: ID,
) {
    if (cap.config_id().is_some()) {
        err_config_already_created();
    };
    cap.config_id.fill(config_id);
}

public(package) fun set_status_id<P>(
    cap: &mut AdminCap<P>,
    status_id: ID,
) {
    if (cap.status_id().is_some()) {
        err_status_already_created();
    };
    cap.status_id.fill(status_id);
}

//***********************
//  Getter Funs
//***********************

public fun config_id<P>(cap: &AdminCap<P>): &Option<ID> {
    &cap.config_id
}

public fun status_id<P>(cap: &AdminCap<P>): &Option<ID> {
    &cap.status_id
}

//***********************
//  Test-only Funs
//***********************

#[test_only]
public fun new_for_testing<P: drop>(ctx: &mut TxContext): AdminCap<P> {
    let otw = sui::test_utils::create_one_time_witness<P>();
    new(otw, ctx)
}
