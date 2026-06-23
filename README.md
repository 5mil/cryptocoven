# Crypto Coven Mining Setup Guide
### Connecting to Mining-Dutch.nl — Party "coven"

This guide helps you set up mining for the Crypto Coven party on Mining-Dutch.nl.
Party mining pools group hashrate together for better block-solving chances.

## 1. Create an Account

Register or log in at [Mining-Dutch.nl](https://www.mining-dutch.nl).

## 2. Select Your Algorithm

After logging in, use the **algorithm drop-down menu on the main page** to select
the algorithm you want to configure (e.g. the one FNNC uses).

## 3. Configure Miner Settings

Navigate to the **Workers** page, then go to **Settings → Customize miner configuration**
and set the following:

- **Miner Group:** Select your miner group
- **Coin / Set:** `FNNC`
- **Mining Mode:** `PARTY mining`
- **Party ID:** `coven`

Click **Apply Settings**.

> ⚠️ No reward will be given if no PARTY miner solves blocks. Use at your own risk.

## 4. Point Your Miner at the Pool

Use the Mining-Dutch stratum URL for your algorithm and region:

- **Stratum:** `stratum+tcp://[algorithm].mining-dutch.nl:[port]`
- **Username:** `YourUsername.WorkerName`
- **Password:** `x`

Any worker in the configured miner group will automatically mine FNNC in PARTY
mode under the `coven` party.

## 5. Payouts & Monitoring

Set up your FNNC wallet address under the **Wallets** section.
Monitor earnings from the dashboard.

---

For full details, visit
[mining-dutch.nl/index.php?page=gettingstarted](https://www.mining-dutch.nl/index.php?page=gettingstarted)
