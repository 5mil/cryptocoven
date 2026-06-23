# Crypto Coven Mining Setup Guide
### Connecting to Mining-Dutch.nl — Party "coven"

This guide walks you through joining the Crypto Coven PARTY mining group on [Mining-Dutch.nl](https://www.mining-dutch.nl). FNNC (Fennec) uses the **YescryptR16** algorithm.

---

## 1. Create an Account

Register or log in at [Mining-Dutch.nl](https://www.mining-dutch.nl).

---

## 2. Select Your Algorithm

After logging in, use the **algorithm drop-down in the top-right corner of the main page** and select `yescryptr16`. All pages and settings on the site are algorithm-specific — select this before proceeding.

---

## 3. Configure Your Worker for PARTY Mining

Go to the **Workers** page and open **Settings → Customize miner configuration**. Apply the following:

| Field | Value |
|---|---|
| Miner Group | *(select your miner group)* |
| Coin / Set | `FNNC` |
| Mining Mode | `PARTY mining` |
| Party ID | `coven` |

Click **Apply Settings**.

> ⚠️ No reward will be given if no PARTY miner solves a block. Use at your own risk.

---

## 4. Point Your Miner at the Pool

Stratum URL format:

| Region | URL Format |
|---|---|
| Europe | `stratum+tcp://yescryptr16.mining-dutch.nl:[port]` |
| Asia | `stratum+tcp://asia.yescryptr16.mining-dutch.nl:[port]` |
| North America | `stratum+tcp://americas.yescryptr16.mining-dutch.nl:[port]` |

For your exact port based on your difficulty level (Low / Lowest / High), use the [Miner Settings Generator](https://www.mining-dutch.nl/index.php?page=gettingstarted).

**Miner credentials:**
- **Username:** `YourUsername.WorkerName`
- **Password:** `x`

---

## 5. Set Up Your Wallet

Go to the **Wallets** section on Mining-Dutch and add your FNNC wallet address (addresses start with `F`).

---

## 6. Monitor Your Mining

Track hashrate, shares, and earnings from the Mining-Dutch dashboard. Earnings are pooled across all members mining under the `coven` party ID.

---

## All Supported Algorithms & Coins

Mining-Dutch supports the following algorithms. Switch algorithms using the top-right drop-down. For full per-coin stratum ports, visit the [Getting Started page](https://www.mining-dutch.nl/index.php?page=gettingstarted).

| Algorithm | Hardware | Notable Coins |
|---|---|---|
| `sha256` | ASIC | BTC, BCH, BSV, DGB (SHA256), PPC, FCH, SPACE, ACG, WJK, QUAI, XEC, XRG, XMY, XBT, BCH2, BC2, BTCS, DVT, FIX, FB |
| `scrypt` | ASIC / GPU | LTC, DOGE, FTC, LC2 |
| `kawpow` | GPU | RVN, FIRO, and others |
| `randomx` | CPU | XMR and others |
| `yescryptr16` | CPU | **FNNC (Fennec)** |
| `yescryptr32` | CPU | Various Yescrypt variants |
| `yescrypt` | CPU | Various Yescrypt coins |
| `yespower` | CPU | Various Yespower coins |
| `yespowerr16` | CPU | Various Yespower R16 coins |
| `equihash` | GPU / ASIC | ZEC and others |
| `equihash_gpu` | GPU | GPU-optimized Equihash coins |
| `ghostrider` | CPU / GPU | RTM (Raptoreum) and others |
| `groestl` | GPU | GRS (Groestlcoin) and others |
| `handshake` | ASIC / GPU | HNS (Handshake) |
| `k12` | CPU / GPU | Various |
| `keccak` | ASIC / GPU | Various |
| `lbry` | GPU | LBC (LBRY Credits) |
| `lyra2rev2` | GPU | VTC, Mona, and others |
| `neoscrypt` | GPU | Feathercoin, Orbitcoin, and others |
| `odocrypt` | FPGA | DGB (Odocrypt) |
| `qubit` | GPU | DGB (Qubit) and others |
| `skein` | GPU | DGB (Skein) and others |
| `skydogehash` | GPU | SKYDOGE and others |
| `verthash` | GPU | VTC (Vertcoin) |
| `x11` | ASIC / GPU | DASH and others |
| `x13` | GPU | Various X13 coins |

> Each algorithm has its own stratum subdomain: `stratum+tcp://[algorithm].mining-dutch.nl:[port]`
> For Asian servers prefix with `asia.`, for North American servers prefix with `americas.`

---

For full pool documentation, visit [mining-dutch.nl/index.php?page=gettingstarted](https://www.mining-dutch.nl/index.php?page=gettingstarted)
