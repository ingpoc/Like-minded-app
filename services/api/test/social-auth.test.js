const assert = require("node:assert/strict");
const test = require("node:test");
const crypto = require("node:crypto");
const { Wallet } = require("ethers");
const nacl = require("tweetnacl");
const bs58 = require("bs58").default;

const { verifyGoogleIdentityToken } = require("../src/lib/google-auth");
const {
  createWalletChallenge,
  consumeWalletChallenge,
  verifyWalletSignature
} = require("../src/lib/wallet-auth");
const { upsertWalletUser, upsertGoogleUser } = require("../src/lib/mvp-store");

const originalEnv = { ...process.env };

test.afterEach(() => {
  process.env = { ...originalEnv };
});

test("verifyGoogleIdentityToken bypass mode works", async () => {
  process.env.GOOGLE_AUTH_BYPASS = "1";
  const payload = await verifyGoogleIdentityToken("google-test-token");
  assert.ok(payload.sub.startsWith("dev-google-"));
});

test("wallet challenge and ethereum verification round-trip", async () => {
  process.env.WALLET_AUTH_BYPASS = "0";
  const wallet = Wallet.createRandom();
  const challenge = createWalletChallenge({ wallet: "metamask" });
  const signature = await wallet.signMessage(challenge.message);
  const verifiedAddress = verifyWalletSignature({
    chain: "ethereum",
    message: challenge.message,
    signature,
    address: wallet.address
  });
  assert.equal(verifiedAddress, wallet.address);
  consumeWalletChallenge(challenge.id);
});

test("wallet challenge and solana verification round-trip", async () => {
  process.env.WALLET_AUTH_BYPASS = "0";
  const keypair = nacl.sign.keyPair();
  const address = bs58.encode(keypair.publicKey);
  const challenge = createWalletChallenge({ wallet: "solflare" });
  const messageBytes = Buffer.from(challenge.message, "utf8");
  const signature = bs58.encode(nacl.sign.detached(messageBytes, keypair.secretKey));
  const verifiedAddress = verifyWalletSignature({
    chain: "solana",
    message: challenge.message,
    signature,
    address
  });
  assert.equal(verifiedAddress, address);
});

test("upsertGoogleUser and upsertWalletUser create distinct users locally", async () => {
  process.env.LIKEMINDED_DB_DIR = `/tmp/likeminded-auth-test-${crypto.randomBytes(6).toString("hex")}`;
  const googleUser = await upsertGoogleUser({
    googleSub: "google-sub-test",
    email: "google@likeminded.local",
    fullName: "Google User"
  });
  const walletUser = await upsertWalletUser({
    walletChain: "ethereum",
    walletAddress: "0x1234567890123456789012345678901234567890"
  });
  assert.notEqual(googleUser.id, walletUser.id);
  assert.equal(googleUser.authProvider, "google");
  assert.equal(walletUser.authProvider, "wallet");
});
