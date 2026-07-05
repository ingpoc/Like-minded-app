const crypto = require("node:crypto");
const { verifyMessage, getAddress } = require("ethers");
const { PublicKey } = require("@solana/web3.js");
const nacl = require("tweetnacl");
const bs58 = require("bs58").default;

const CHALLENGE_TTL_MS = 5 * 60 * 1000;
const challenges = new Map();

function normalizeWallet(value) {
  const wallet = String(value || "").trim().toLowerCase();
  if (wallet === "metamask" || wallet === "solflare") return wallet;
  throw new Error("invalid_wallet");
}

function normalizeChain(value) {
  const chain = String(value || "").trim().toLowerCase();
  if (chain === "ethereum" || chain === "solana") return chain;
  throw new Error("invalid_chain");
}

function walletChainForWallet(wallet) {
  return wallet === "metamask" ? "ethereum" : "solana";
}

function purgeExpiredChallenges() {
  const now = Date.now();
  for (const [id, challenge] of challenges.entries()) {
    if (challenge.expiresAt <= now) challenges.delete(id);
  }
}

function buildSignMessage({ chain, wallet, nonce }) {
  const issuedAt = new Date().toISOString();
  const uri = process.env.WALLET_AUTH_URI || "https://likeminded.app";
  if (chain === "ethereum") {
    return [
      `${uri} wants you to sign in with your Ethereum account using ${wallet}.`,
      "",
      "Sign in to Likeminded",
      "",
      `URI: ${uri}`,
      "Version: 1",
      "Chain ID: 1",
      `Nonce: ${nonce}`,
      `Issued At: ${issuedAt}`
    ].join("\n");
  }

  return [
    "Likeminded wants you to sign in with your Solana account using Solflare.",
    "",
    "Sign in to Likeminded",
    "",
    `URI: ${uri}`,
    `Nonce: ${nonce}`,
    `Issued At: ${issuedAt}`
  ].join("\n");
}

function createWalletChallenge({ wallet, chain }) {
  purgeExpiredChallenges();
  const normalizedWallet = normalizeWallet(wallet);
  const normalizedChain = chain ? normalizeChain(chain) : walletChainForWallet(normalizedWallet);
  if (walletChainForWallet(normalizedWallet) !== normalizedChain) {
    throw new Error("wallet_chain_mismatch");
  }

  const challengeId = crypto.randomBytes(16).toString("hex");
  const nonce = crypto.randomBytes(16).toString("hex");
  const message = buildSignMessage({ chain: normalizedChain, wallet: normalizedWallet, nonce });
  const expiresAt = Date.now() + CHALLENGE_TTL_MS;
  const challenge = {
    id: challengeId,
    wallet: normalizedWallet,
    chain: normalizedChain,
    nonce,
    message,
    expiresAt
  };
  challenges.set(challengeId, challenge);
  return challenge;
}

function getWalletChallenge(challengeId) {
  purgeExpiredChallenges();
  const challenge = challenges.get(String(challengeId || ""));
  if (!challenge) throw new Error("wallet_challenge_not_found");
  if (challenge.expiresAt <= Date.now()) {
    challenges.delete(challenge.id);
    throw new Error("wallet_challenge_expired");
  }
  return challenge;
}

function consumeWalletChallenge(challengeId) {
  const challenge = getWalletChallenge(challengeId);
  challenges.delete(challenge.id);
  return challenge;
}

function verifyEthereumSignature({ message, signature, address }) {
  const recovered = verifyMessage(message, signature);
  const expected = getAddress(address);
  if (getAddress(recovered) !== expected) {
    throw new Error("wallet_signature_mismatch");
  }
  return expected;
}

function verifySolanaSignature({ message, signature, address }) {
  const publicKey = new PublicKey(address);
  const signatureBytes = bs58.decode(signature);
  const messageBytes = Buffer.from(message, "utf8");
  const verified = nacl.sign.detached.verify(messageBytes, signatureBytes, publicKey.toBytes());
  if (!verified) throw new Error("wallet_signature_mismatch");
  return publicKey.toBase58();
}

function verifyWalletSignature({ chain, message, signature, address }) {
  if (process.env.WALLET_AUTH_BYPASS === "1") {
    const normalized = String(address || "wallet-tester").trim();
    if (!normalized) throw new Error("wallet_address_missing");
    return normalized;
  }

  const normalizedChain = normalizeChain(chain);
  if (normalizedChain === "ethereum") {
    return verifyEthereumSignature({ message, signature, address });
  }
  return verifySolanaSignature({ message, signature, address });
}

function walletAuthSubject(chain, address) {
  return `${chain}:${String(address).toLowerCase()}`;
}

module.exports = {
  createWalletChallenge,
  getWalletChallenge,
  consumeWalletChallenge,
  verifyWalletSignature,
  walletAuthSubject,
  normalizeWallet,
  normalizeChain,
  walletChainForWallet
};
