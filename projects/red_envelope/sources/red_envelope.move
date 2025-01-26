module red_envelope::red_envelope;

use red_envelope::admin::{AdminCap};

public struct RedEnvelope<phantom T> has key, store {
    id: UID,
}

public fun create_to<T>(
    _cap: &AdminCap,
    recipient: address,
    ctx: &mut TxContext,
) {
    let e = RedEnvelope<T> { id: object::new(ctx) };
    transfer::transfer(e, recipient);
}
