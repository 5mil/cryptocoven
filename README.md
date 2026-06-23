# Crypto Coven Mining Setup Guide
### Connecting to Mining-Dutch.nl — Party "coven"

This guide walks you through joining the Crypto Coven PARTY mining group on [Mining-Dutch.nl](https://www.mining-dutch.nl). FNNC (Fennec) uses the **YescryptR16** algorithm, which is CPU/GPU-friendly and ASIC-resistant.

---

## 1. Create an Account

Register or log in at [Mining-Dutch.nl](https://www.mining-dutch.nl).

---

## 2. Select the YescryptR16 Algorithm

After logging in, use the **algorithm drop-down menu in the top-right corner of the main page** and select `yescryptr16`. All settings and pages on the site are algorithm-specific — make sure this is selected before proceeding.

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

Use the following stratum URLs for the YescryptR16 algorithm. Choose the region closest to you.

**European servers:**
```
stratum+tcp://yescryptr16.mining-dutch.nl:[port]
```

**Asian servers:**
```
stratum+tcp://asia.yescryptr16.mining-dutch.nl:[port]
```

**North American servers:**
```
stratum+tcp://americas.yescryptr16.mining-dutch.nl:[port]
```

Use the [Miner Settings Generator](https://www.mining-dutch.nl/index.php?page=gettingstarted) on the Getting Started page to get the exact port for your difficulty level (Low / Lowest / High).

**Miner credentials:**
- **Username:** `YourUsername.WorkerName`
- **Password:** `x`

---

## 5. Set Up Your Wallet

Go to the **Wallets** section on Mining-Dutch and add your FNNC wallet address (addresses start with `F`). This is required for payouts.

---

## 6. Monitor Your Mining

Track hashrate, shares, and earnings from the Mining-Dutch dashboard. Earnings are pooled across all members mining under the `coven` party ID.

---

For full pool documentation, visit [mining-dutch.nl/index.php?page=gettingstarted](https://www.mining-dutch.nl/index.php?page=gettingstarted)
