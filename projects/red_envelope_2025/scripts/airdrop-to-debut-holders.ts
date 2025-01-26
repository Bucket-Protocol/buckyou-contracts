import { Transaction } from "@mysten/sui/transactions";
import { OwnedObjectRef } from "@mysten/sui/client";
import {
  client,
  signer,
  RED_ENVELOPE_2025_PACKAGE_ID,
  ADMIN_CAP_ID,
} from "./config";
import debutHolderTiers from "./debut-holder-tiers.json";

const DEBUT_HOLDER_TYPE = 1;

async function main() {
  const totalSize = debutHolderTiers.length;
  console.log(totalSize);

  let gasCoin: OwnedObjectRef | undefined = undefined;
  const maxStep = 128;
  let cursor = 0;
  let step = maxStep;
  let tx: Transaction;

  while (cursor < totalSize) {
    console.log(cursor, step, cursor + step);
    try {
      tx = new Transaction();
      const adminCapObj = tx.object(ADMIN_CAP_ID);
      debutHolderTiers
        .slice(cursor, cursor + step)
        .map(({ account, amount }) => {
          tx.moveCall({
            target: `${RED_ENVELOPE_2025_PACKAGE_ID}::red_envelope_2025::batch_airdrop`,
            arguments: [
              adminCapObj,
              tx.pure.u8(DEBUT_HOLDER_TYPE),
              tx.pure.u64(amount),
              tx.pure.address(account),
            ],
          });
        });
      tx.setGasBudget(1_000_000_000);
      tx.setSender(signer.toSuiAddress());
      if (gasCoin) tx.setGasPayment([gasCoin.reference]);
      const res = await client.signAndExecuteTransaction({
        transaction: tx,
        signer,
        options: {
          showEffects: true,
        },
      });
      console.log(res.digest);
      gasCoin = res.effects?.gasObject;

      cursor = cursor + step;
      step = step * 2;
      if (step > maxStep) step = maxStep;
    } catch (err) {
      console.log(err);
      step = Math.ceil(step / 2);
    } finally {
      await new Promise((r) => setTimeout(r, 10_000));
    }
  }
}

main().catch((err) => console.log(err));
