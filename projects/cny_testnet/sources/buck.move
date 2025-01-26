module cny_testnet::buck;

use sui::coin;

public struct BUCK has drop {}

fun init(otw: BUCK, ctx: &mut TxContext) {
    let (cap, metadata) = coin::create_currency(
        otw,
        9,
        b"BUCK",
        b"Bucket Stablecoin",
        b"",
        option::none(),
        ctx,
    );
    transfer::public_transfer(cap, ctx.sender());
    transfer::public_transfer(metadata, ctx.sender());
}