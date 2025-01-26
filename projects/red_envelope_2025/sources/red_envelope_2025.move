module red_envelope_2025::red_envelope_2025;

use std::string::utf8;
use sui::package;
use sui::display;
use red_envelope_2025::admin::{AdminCap};

public struct RED_ENVELOPE_2025 has drop {}

public struct Airdrop has copy, drop {
    id: ID,
    kind: u8,
    recipient: address,
}

public struct RedEnvelope2025 has key, store {
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
    let mut displayer = display::new_with_fields<RedEnvelope2025>(
        &publisher, keys, values, ctx,
    );
    display::update_version(&mut displayer);
    transfer::public_transfer(displayer, deployer);
    transfer::public_transfer(publisher, deployer);
}

fun new(
    _cap: &AdminCap,
    kind: u8,
    ctx: &mut TxContext,
): RedEnvelope2025 {
    RedEnvelope2025 { id: object::new(ctx), kind }
}

public fun airdrop(
    cap: &AdminCap,
    kind: u8,
    recipient: address,
    ctx: &mut TxContext,
) {
    let e = new(cap, kind, ctx);
    sui::event::emit(Airdrop {
        id: object::id(&e),
        kind,
        recipient,
    });
    transfer::transfer(e, recipient);
}

public fun batch_airdrop(
    cap: &AdminCap,
    kind: u8,
    count: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    count.do!(|_| {
        airdrop(cap, kind, recipient, ctx);
    });
}
