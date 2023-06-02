import { blake2b } from "@noble/hashes/blake2b";
import {
  SerializedSignature,
  toSerializedSignature,
  JsonRpcProvider,
  SuiAddress,
  SignerWithProvider,
  Ed25519PublicKey,
} from "@mysten/sui.js";
import Sui from "@mysten/ledgerjs-hw-app-sui";
import TransportNodeHid from "@ledgerhq/hw-transport-node-hid-singleton";

const PATH = "44'/784'/0'/0'/0'";

export class HDSigner extends SignerWithProvider {
  //       this.sui = new Sui(await Transport.create());

  constructor(provider: JsonRpcProvider) {
    super(provider);
  }

  async getSinger(): Promise<Sui> {
    return new Sui(await TransportNodeHid.create());
  }

  async getPublicKey(): Promise<Ed25519PublicKey> {
    const sui = await this.getSinger();
    const pk = await sui.getPublicKey(PATH);

    const publicKey =  new Ed25519PublicKey(pk.publicKey);
    console.log("public key of HD wallet: ", publicKey.toString(), publicKey.toSuiAddress());
    return publicKey;
  }

  async getAddress(): Promise<SuiAddress> {
    return (await this.getPublicKey()).toSuiAddress();
  }

  async signData(data: Uint8Array): Promise<SerializedSignature> {
    const pubkey = await this.getPublicKey();

    //const digest = blake2b(data, { dkLen: 32 });
    const result = await (await this.getSinger()).signTransaction(PATH, data);
    const signature = result.signature;
    const signatureScheme = "ED25519";

    return toSerializedSignature({
      signatureScheme,
      signature,
      pubKey: pubkey,
    });
  }

  connect(provider: JsonRpcProvider): SignerWithProvider {
    return new HDSigner(provider);
  }
}
