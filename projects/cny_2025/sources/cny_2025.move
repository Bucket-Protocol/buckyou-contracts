module cny_2025::cny_2025;

use sui::sui::SUI;
use liquidlogic_framework::float;
use buckyou_core::admin;
use buckyou_core::config;
use buckyou_core::status;
use buckyou_core::pool;
use buckyou_core::step_price::{Self, STEP_PRICE_RULE};
use bucket_protocol::buck::{BUCK};
use but::but::{BUT};
use red_envelope_2025::red_envelope_2025::{RedEnvelope2025};

public fun period(): u64 { 86400_000 }
public fun sui_price_step(): u64 { 1_000_000_000 }
public fun buck_price_step(): u64 { 4_000_000_000 }
public fun but_price_step(): u64 { 150_000_000_000 }

// otw
public struct CNY_2025 has drop {}

// init
#[allow(lint(share_owned))]
fun init(otw: CNY_2025, ctx: &mut TxContext) {
    let mut cap = admin::new(otw, ctx);
    // create config
    let config = config::new(
        &mut cap,
        float::from_percent(35),
        float::from_percent(45),
        float::from_percent(10),
        vector[10, 20, 30, 40].map!(|percent| float::from_percent(percent)),
        10,
        float::from_percent(90),
        period(),
        60_000,
        period(),
        ctx,
    );
    
    // create status
    let (mut status, starter) = status::new(&mut cap, 10, ctx);
    status.start(&config, starter, 1737892800000); // start at UTC 20250126 12:00

    // whitelist red envelope 2025
    status.add_voucher_type<CNY_2025, RedEnvelope2025>(&cap);

    // whitelist referrers
    let referrers = vector[
        @0x6f94ac3e8f1a8a1d22d7ecc399451aa3b872621f15357f5b8d463c3a5a1ec1fd,
        @0x0760564b88d4d86026aec8c4b0ca695187174ac8138cb9e9a37c7837546039cb,
        @0xef1304f95ba1e93f211a033eea6c39245bc0b9626f2242788ff0a1283ead9a14,
        @0x68aec368ab71e547ac1441cff76406b15239076a70916badb7455e3cfffacc66,
        @0x96d9a120058197fce04afcffa264f2f46747881ba78a91beb38f103c60e315ae,
        @0xd94414fabb3930998c99696331b49a4fe60372abb0618a22714a0123bfc876b2,
        @0xff58e2712cdb15eb725bbf1e47227b7d67ca15ad74c89e055e2507b40cd4bfe7,
        @0x10eefc7a3070baa5d72f602a0c89d7b1cb2fcc0b101cf55e6a70e3edb6229f8b,
        @0x0eedbead80be8c6fa965fa887d4c70fced9c562d455473dd244a85c9994780d7,
        @0x08256b51ffc657f02b8ff6e424723869abd521020d70f48f77dd497302a40aa6,
        @0x47ab00599d8d7f64bfd0cf306835912449b5a50fe64cfda3294b51e1d3e2a714,
        @0xb8f22bd00e7e769099a99dd69d16cc37c8a16703ce6f7fcc1ad998c84d6ceff1,
        @0xe96c321436db7f3b2fef2c53b1522deb904c7a318112fa1e7459dcd37058c03b,
        @0xfcd5f2eee4ca6d81d49c85a1669503b7fc8e641b406fe7cdb696a67ef861492c,
        @0x7f608bbe692ecaa5795a2d85cf9894846dfdb24aab22c98478b18255109e92b4,
        @0xfb9ea15f4b1102cd3ed16e89e588612a653c357f96203300364280f8f3da98cf,
        @0x750efb8f6d1622213402354bfafb986ac5674c2066e961badf83c7ccd2dc5505,
        @0xfa1d64cde7526b75a4d04c1804e00fb694bfd9e8a95bb18fdde1883b3aa5a93e,
        @0xf5ad86df467d1d945072aafc047413b8cf9e6237f9505ea63c3612ee7ecf0306,
        @0xf64c0c61d5742c1ce86d1632e5d857fac1f2bf166f19c5a7fa13b30ea5089f01,
        @0x51aed3b31497c50c6eac67cac9269e05fd1e19ac92c280b8cfdfe3152e7fab26,
        @0x70ff48b242fc7ad68e34e4c999318e43b393c2fe3e08b478c92d13480cefc9d7,
        @0xd62aff12be91fd14a3b952af19c83a4173952dad69d359d35dca06b758230415,
        @0xe1868a9f44b569ab6fa722022403520bd93fe20b06091785e33db644858c0a81,
        @0x7bc9ed4228e908fc58b1a012ad9ea62d95fcc864203aa0e60cef70d1c4124951,
        @0x7b2186cff92f5b1c16272a8ec26fa0965dd02b2366f6d1e0c7e1afe1fcf3412b,
        @0x5594a8397b5d373a7fdb887844bd376c123b3bcd8ae9eb790eebaa4a9b24735d,
        @0xc1b4abd6ec3c8417bea91cdb517dcbffc2cd963ffc9b76056c09183f55486042,
        @0x8c3026cdca74f2dfaece33c1fc311f1c95fd0a3484114c1764035a62d81e30bc,
        @0xff56d23a4c67ace448442f8902b4c6468b8cb4aefe34f5eacc68470bb22a2dd7,
        @0xed7ba9119e330d5032637eb573a4078e6c80c2ae17e3c77382a90fc2fe640f92,
        @0x0ed670c2457a6f3902d001f8613b36da8aaddc8372a02f4764e5a24117aa670b,
        @0x659a381846ce993e889be7fa047f6ccf82ac20fd90995a47b481e62fd56ff772,
        @0x63caf24ab6dfc41c44fd67e7e117e2f0a4ef0f636fed9ddddde2f1bd230bae8e,
        @0xac8970f676b95433cabf917a667c7cdc791b41f9a1c06436808dab1f3ec5220d,
        @0x74bd991f694eb5792c10c3715a125629da67a0494e95b299ae23264210a53cf5,
        @0xe59cb9a7b0eb75eb4ed409e93185c42436fa3231de091a25c23667466e58ebc7,
        @0x6f6f4df6532ac345cb705033b81342139516160437068f8e16b1526b21a77dd4,
        @0x8b8bbb50e641024735c1e957b72fa3dd6d9ff389c17064119100b16ec22014e3,
        @0xfea3e95fefaae7a4396d65909c4611220de51ee6819098702ccfcf1a87e4f998,
        @0x1287280ae3ec05a4ba76a450a51c002b336ffe84926f3213e85468add27d6e5e,
        @0xf1b26d7e90a81f038346b7fbf7a08d904631fd688d2cae80d77e05d3d903e0eb,
        @0xa96b93a18645cbffd83430c7dd2267ec057ae8d0fb6a853eb0f87d207b913c17,
        @0xe4fa0f68560d7c24d0618021ece37d1c0630ba5ac1aacbdd534378dc02c6aa2e,
        @0x8e6de426521587efe28a0837567a030fb217f7e21bac6c9e18dc148e5e8a2c87,
        @0xf5a6f95e21917272a1e2858211ed6c9d349892db3652c6d3e847a9dc93ed312a,
        @0x3912e71fd5de1f6c97df59119c5c3ab2bdd4228d93dd86123a6812b4623fa338,
        @0x3a0df0d81b3ea821796ed3fc030e7bb9ab9c354e3a4b017373805aa5e8a0ccf4,
        @0xafa2f1f01037f2e3eabf98f5f2e49c2c27945586276317eaf9e003adeae3c936,
        @0x44475d93ed75ea02137e3997b300387586bb21fc233e4b971178408451ebb7ae,
        @0x5f75c4f73c527df7bb001b5eaf6634f632840ed49da3d6b2ec9f446c64f846be,
        @0x64b0ca8f440966a9866b46c04a8921d5a046f409f2ae4dce240fc9a8538f3dcb,
        @0x553445850af10250f13bc6404330fc69d3d7c31de85626e1657ada51ba866266,
        @0x9bd20567adf49934d01b1593dac62f4e685062a71241a0f7b96ae09ab7e6c813,
        @0xd70864e5de586870557401e84bf212baaca0e3c7f3609fed148b0fa736116565,
        @0x68691f8e1609c91b389a55d0c7e02f426df4d79b433c6717200d4444cae3311c,
        @0x8cfed27f37d4c465129577a88afe257ebac56b1bd10cfd5f7858b1915d367a20,
        @0xb9bc14a75a633e84b06372a0dd373f610e0d183c4232b53f9a1ad58bda3653bc,
        @0x7f9c74a94069e980195fe4b75eb75b0bfd4f91d008da8e8f99b019fa135c7df2,
        @0x037751cd6e296dd1aa23552ba00fbf804a69c8a27c6c4cd04a3252f8809b7dcb,
        @0x40061c709edb896ad029c500de2aee3ef58a062a4b3bd05235d5ae3df6586d8b,
        @0x5cd1a2caf38093a5c1a0e30de5c1fea6a5e909b7a8a2eca3bfb927f38a7a96f3,
        @0x525a570bdd47d407d70a070dd915d550ae1a9069d84de08e718f5495e86715c8,
        @0x777f19488e45550f56e968ce6aff0e5aecb850a9718e083412fb762517b358bc,
        @0x1cbe6f4ba96cfcdf50d60512bf2391af9133a9253c23797eb84e69bb151c368e,
        @0x1cabbf164d13044f32e34cd075c1bd90596af9798e187d89035aa56d2683267c,
        @0xbcf5a725b72f88fd50c7146a48822fc61e3691cbe44193a668887de4573764ca,
        @0xd02753f655e5e41c167a381f6e1abfcce6e766556ec387e3260c90b016c15e02,
        @0x8fd8019a60e7652f786a4e7ef7f6fac85d5278acb142beaf04700d4b054513d5,
        @0xcd8ce0e3a4291132f1d57494b5f86021212a7def4585ee7db96ff94d106ec307,
        @0x9b49a546ee488ae2b5a8add127d0da8e056365ef1fdbc6f8b88fe26aba75610e,
        @0xf8e104b93ef573725859870bb549c6108e67bcd682842d67ac2794ec527477f4,
        @0xf2164bc3634b87dca87b5fc280d998e5d7dc6e44f1228191c560ce803ed40bfa,
        @0x83c84e05ff168187cd0c22a3bbc2afeb90873ae0de47ab2f3f43c2079d3bd05a,
    ];
    referrers.do!(|referrer| {
        status.add_referrer(&cap, referrer);
    });

    // create sui pool and price rule
    let mut pool = pool::new<CNY_2025, SUI>(&cap, &mut status, ctx);
    let price_rule = step_price::new<CNY_2025, SUI>(
        &cap,
        sui_price_step(),
        period(),
        sui_price_step(),
        float::from(1),
        ctx,
    );
    pool.add_rule<CNY_2025, SUI, STEP_PRICE_RULE>(&cap);
    transfer::public_share_object(price_rule);
    transfer::public_share_object(pool);

    // create buck pool and price rule
    let mut pool = pool::new<CNY_2025, BUCK>(&cap, &mut status, ctx);
    let price_rule = step_price::new<CNY_2025, BUCK>(
        &cap,
        buck_price_step(),
        period(),
        buck_price_step(),
        float::from(1),
        ctx,
    );
    pool.add_rule<CNY_2025, BUCK, STEP_PRICE_RULE>(&cap);
    transfer::public_share_object(price_rule);
    transfer::public_share_object(pool);

    // create but pool and price rule
    let mut pool = pool::new<CNY_2025, BUT>(&cap, &mut status, ctx);
    let price_rule = step_price::new<CNY_2025, BUT>(
        &cap,
        but_price_step(),
        period(),
        but_price_step(),
        float::from(1),
        ctx,
    );
    pool.add_rule<CNY_2025, BUT, STEP_PRICE_RULE>(&cap);
    transfer::public_share_object(price_rule);
    transfer::public_share_object(pool);

    transfer::public_share_object(config);
    transfer::public_share_object(status);
    transfer::public_transfer(cap, ctx.sender());
}