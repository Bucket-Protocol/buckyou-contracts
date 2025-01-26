import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { signerPrivKey, rpcUrl } from "./env.json";

export const client = new SuiClient({
  url: rpcUrl.length > 0 ? rpcUrl : getFullnodeUrl("mainnet"),
});

export const signer = Ed25519Keypair.fromSecretKey(signerPrivKey);

export const RED_ENVELOPE_2025_PACKAGE_ID =
  "0xc955c9c7e858f9055f6de56dea385e90d4bc650f8bb03323a9de4fc7d88b0261";

export const ADMIN_CAP_ID =
  "0x5421239a7b43e85d637cad9e078f3e54aed4b72f53fda6bfad4b5ddd4a9603c0";
