module red_envelope::red_envelope_2025;

use std::string::utf8;
use sui::package;
use sui::display;
use red_envelope::admin::{AdminCap};

public struct RED_ENVELOPE_2025 has drop {}

public struct RedEnvelope has key, store {
    id: UID,
    kind: u8,
}

fun init(otw: RED_ENVELOPE_2025, ctx: &mut TxContext) {
    let keys = vector[
        utf8(b"name"),
        utf8(b"description"),
        utf8(b"image_url"),
        utf8(b"project_url"),
        utf8(b"creator"),
    ];

    let values = vector[
        // name
        utf8(b"BuckYou Red Envelope 2025"),
        // description
        utf8(b"Go claim your shares at https://cny.buckyou.io !"),
        // image_url
        utf8(b"https://aqua-natural-grasshopper-705.mypinata.cloud/ipfs/Qmeyz3FijdgyR9AMqg84nzpQR4sXbZd1M4UBhQ9Dz99sYE"),
        // project_url
        utf8(b"https://cny.buckyou.io/"),
        // creator
        utf8(b"buckyou"),
    ];

    let deployer = tx_context::sender(ctx);
    let publisher = package::claim(otw, ctx);
    let mut displayer = display::new_with_fields<RedEnvelope>(
        &publisher, keys, values, ctx,
    );
    display::update_version(&mut displayer);
    transfer::public_transfer(displayer, deployer);
    transfer::public_transfer(publisher, deployer);
}

public fun new(
    _cap: &AdminCap,
    kind: u8,
    ctx: &mut TxContext,
): RedEnvelope {
    RedEnvelope { id: object::new(ctx), kind }
}

public fun create_to(
    cap: &AdminCap,
    kind: u8,
    recipient: address,
    ctx: &mut TxContext,
) {
    let e = new(cap, kind, ctx);
    transfer::transfer(e, recipient);
}

public fun batch_create_to(
    cap: &AdminCap,
    kind: u8,
    count: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    count.do!(|_| {
        create_to(cap, kind, recipient, ctx);
    });
}
