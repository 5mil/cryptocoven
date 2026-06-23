# Crypto Coven Mining Setup Guide
### Connecting to Mining-Dutch.nl — Party "coven"

This guide walks you through joining the Crypto Coven PARTY mining group on [Mining-Dutch.nl](https://www.mining-dutch.nl). PARTY mining pools the hashrate of everyone using the same Party ID, increasing the group's chances of solving blocks together.

This guide works for **any algorithm and any coin** supported by Mining-Dutch. See [COINS.md](./COINS.md) for the full list of coins, markets, difficulty tiers, and Lazy Mining (auto-swap) status.

---

## 1. Create an Account

Register or log in at [Mining-Dutch.nl](https://www.mining-dutch.nl).

---

## 2. Select Your Algorithm

After logging in, use the **algorithm drop-down in the top-right corner of the main page** to select the algorithm for the coin you want to mine. All pages and settings on the site are scoped to whichever algorithm is selected.

---

## 3. Configure Your Worker for PARTY Mining

Go to the **Workers** page and open **Settings → Customize miner configuration**. Apply the following:

| Field | Value |
|---|---|
| Miner Group | *(select your miner group)* |
| Coin / Set | *(select your coin or coin set)* |
| Mining Mode | `PARTY mining` |
| Party ID | `coven` |

Click **Apply Settings**.

> ⚠️ No reward will be given if no PARTY miner solves a block. Use at your own risk.

---

## 4. Point Your Miner at the Pool

Use the stratum URL for your chosen algorithm and the region closest to you:

| Region | URL Pattern |
|---|---|
| Europe | `stratum+tcp://[algorithm].mining-dutch.nl:[port]` |
| Asia | `stratum+tcp://asia.[algorithm].mining-dutch.nl:[port]` |
| North America | `stratum+tcp://americas.[algorithm].mining-dutch.nl:[port]` |

Replace `[algorithm]` with your algorithm name (e.g. `yescryptr16`, `kawpow`, `sha256`). For your exact port based on your hardware difficulty, use the [Miner Settings Generator](https://www.mining-dutch.nl/index.php?page=gettingstarted).

**Miner credentials:**
- **Username:** `YourUsername.WorkerName`
- **Password:** `x`

---

## 5. Set Up Your Wallet

Go to the **Wallets** section and add the wallet address for whichever coin you are mining.

---

## 6. Monitor Your Mining

Track hashrate, shares, and earnings from the Mining-Dutch dashboard. Earnings are pooled across all Crypto Coven members mining under the `coven` party ID.

---

## Examples

### FNNC (Fennec) — YescryptR16 — CPU

```
Algorithm:  yescryptr16
Coin:       FNNC
Stratum:    stratum+tcp://yescryptr16.mining-dutch.nl:[port]
Username:   YourUsername.WorkerName
Password:   x
```

FNNC wallet addresses start with `F`. Good choice for CPU miners.

---

### RVN (Ravencoin) — KawPow — GPU

```
Algorithm:  kawpow
Coin:       RVN
Stratum:    stratum+tcp://kawpow.mining-dutch.nl:[port]
Username:   YourUsername.WorkerName
Password:   x
```

KawPow is GPU-optimized. Widely supported by miners like T-Rex, NBMiner, and lolMiner.

---

### XMR (Monero) — RandomX — CPU

```
Algorithm:  randomx
Coin:       XMR
Stratum:    stratum+tcp://randomx.mining-dutch.nl:[port]
Username:   YourUsername.WorkerName
Password:   x
```

RandomX is designed for CPUs. Use XMRig for best performance.

---

### DASH — X11 — ASIC / GPU

```
Algorithm:  x11
Coin:       DASH
Stratum:    stratum+tcp://x11.mining-dutch.nl:[port]
Username:   YourUsername.WorkerName
Password:   x
```

X11 supports both ASICs and GPUs. DASH is the highest-value coin on this algorithm at Mining-Dutch.

---

### ZEC (Zcash) — Equihash — GPU / ASIC

```
Algorithm:  equihash
Coin:       ZEC
Stratum:    stratum+tcp://equihash.mining-dutch.nl:[port]
Username:   YourUsername.WorkerName
Password:   x
```

Equihash supports both ASICs and GPUs. ZEC is the highest-value coin on this algorithm.

---

## Full Coin & Algorithm Reference

See [COINS.md](./COINS.md) for every coin available on Mining-Dutch, including:
- Algorithm and hardware type
- Current USD price
- Exchange / market availability
- Lazy Mining (auto-swap) eligibility
- Block probability tier

---

For full pool documentation, visit [mining-dutch.nl/index.php?page=gettingstarted](https://www.mining-dutch.nl/index.php?page=gettingstarted)
