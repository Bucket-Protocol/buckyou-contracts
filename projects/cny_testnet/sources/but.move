module cny_testnet::but;

use sui::coin;

public struct BUT has drop {}

fun init(otw: BUT, ctx: &mut TxContext) {
    let (cap, metadata) = coin::create_currency(
        otw,
        9,
        b"BUT",
        b"Bucket Token",
        b"",
        option::none(),
        ctx,
    );
    transfer::public_transfer(cap, ctx.sender());
    transfer::public_transfer(metadata, ctx.sender());
}