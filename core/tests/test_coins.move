#[test_only]
module buckyou_core::buck {
    public struct BUCK has drop {}
}

#[test_only]
module buckyou_core::but {
    public struct BUT has drop {}
}

#[test_only]
module buckyou_core::voucher {
    public struct Voucher has key, store {
        id: UID,
    }

    public fun new(ctx: &mut TxContext): Voucher {
        Voucher { id: object::new(ctx) }
    }
}