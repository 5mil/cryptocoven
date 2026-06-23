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

Stratum URL format by region:

| Region | URL |
|---|---|
| Europe | `stratum+tcp://yescryptr16.mining-dutch.nl:[port]` |
| Asia | `stratum+tcp://asia.yescryptr16.mining-dutch.nl:[port]` |
| North America | `stratum+tcp://americas.yescryptr16.mining-dutch.nl:[port]` |

For your exact port, use the [Miner Settings Generator](https://www.mining-dutch.nl/index.php?page=gettingstarted).

**Miner credentials:**
- **Username:** `YourUsername.WorkerName`
- **Password:** `x`

---

## 5. Set Up Your Wallet

Go to the **Wallets** section and add your FNNC wallet address (addresses start with `F`).

---

## 6. Monitor Your Mining

Track hashrate, shares, and earnings from the Mining-Dutch dashboard. Earnings are pooled across all members mining under the `coven` party ID.

---

## All Supported Algorithms & Coins

Switch algorithms using the top-right drop-down on the main page. Stratum URL pattern: `stratum+tcp://[algorithm].mining-dutch.nl:[port]` (prefix `asia.` or `americas.` for other regions).

| Algorithm | Hardware | Coins |
|---|---|---|
| `sha256` | ASIC | BTC (Bitcoin), BCH (Bitcoin Cash), BSV (Bitcoin SV), BCH2 (Bitcoin Cash II), BC2 (Bitcoin II), XBT (Bitcoinclassic), XRC (Bitcoin Rhodium), BTCS (Bitcoin Silver), NMC (Namecoin), PPC (Peercoin), XEC (eCash), XRG (Ergon), FCH (FreeCash), SPACE (MVC), ACG (Aurum CryptoGold), WJK (Wojakcoin), QUAI (Quai), DVT (DeVault), FIX (FixedCoin), FB (Fractal Bitcoin) |
| `scrypt` | ASIC / GPU | LTC (Litecoin), DOGE (Dogecoin), FTC (Feathercoin), LC2 (Litecoin II), DINGO (Dingocoin), LKY (Luckycoin), NYC (NewYorkCoin), EAC (Earthcoin), CAT (Catcoin), MOON (Mooncoin), WDC (Worldcoin), JKC (Junkcoin), QUAI (Quai) |
| `kawpow` | GPU | RVN (Ravencoin), KRGN (Kerrigan), NEOX (Neoxa), XNA (Neurai), AIPG (AI Power Grid), SATOX (Satoxcoin), OSMI (Osmium), SHIC (Shiba Inucoin), TRMP (Trumpow), DOGPU (DogeGPU), FREN (Frencoin), FLOP (Flopcoin), SMLP (SmartLoop AI), MECU (MecuAI), SOH (StohnCoin), YERB (Yerbas) |
| `randomx` | CPU | XMR (Monero) |
| `yescryptr16` | CPU | FNNC (Fennec), BELL (Bellcoin), BEL (Bells) |
| `yescryptr32` | CPU | UNFY (Unifyroom), QCH (QuestChain) |
| `yescrypt` | CPU | XMY (Myriadcoin), YTN (Yenten), BSTY (GlobalBoost) |
| `yespower` | CPU | SUBI (SubiNetwork), TCC (Taichicoin), FSC (Fsociety), HOOT (HootChain) |
| `yespowerr16` | CPU | BONC (BonkCoin), LTRM (Litoreum), BTCQ (BTCturquoise), BBC (Babacoin) |
| `equihash` | GPU / ASIC | ZEC (Zcash), ZCL (Zclassic), YEC (Ycash), ARRR (Pirate), KMD (Komodo), CHI (Xaya) |
| `equihash_gpu` | GPU | ZER (Zero), BOLI (Bolivarcoin) |
| `ghostrider` | CPU / GPU | RTM (Raptoreum), MTBC (MateableCoin), BTRM (Bitoreum), MAXI (Maximus), MAXE (Maxeter), TRC (Terracoin) |
| `groestl` | GPU | GRS (Groestlcoin), DMS (Documentchain), GSPC (GSPcoin), IBH (Ibithub) |
| `handshake` | ASIC / GPU | HNS (Handshake) |
| `k12` | CPU / GPU | AEON (Aeon), AIDP (AiDepin) |
| `keccak` | ASIC / GPU | MAX (Maxcoin), MAXE (Maxeter) |
| `lbry` | GPU | LBC (LBRY Credits), LBW (Lebowskiscoin) |
| `lyra2rev2` | GPU | MONA (Monacoin), VTC (Vertcoin), FEC (Ferrite), NET (Netsis) |
| `neoscrypt` | GPU | UFO (Ufocoin), VECO (Veco), GEC (Geckocoin), KUS (Kusa), GUN (Guncoin), DIAC (Diabase) |
| `odocrypt` | FPGA | DGB (Digibyte Odocrypt) |
| `qubit` | GPU | DGB (Digibyte Qubit), BTSC (Bitfishcoin), ARGY (Arsagility), B1T (B1T), XCCX (BlockChainCoinX) |
| `skein` | GPU | DGB (Digibyte Skein), EMC (Emercoin), EPN (EtisPatNet) |
| `skydogehash` | GPU | SKY (Skydoge) |
| `verthash` | GPU | VTC (Vertcoin) |
| `x11` | ASIC / GPU | DASH (Dash), XVG (Verge), ONION (DeepOnion), CY (Cyberyen), RTC (Reaction), TMC (TheMinerzCoin) |
| `x13` | GPU | JGC (Jagoancoin), THOON (Thooneum), GEC (Geckocoin), VHH (Volkshash) |

---

For full pool documentation, visit [mining-dutch.nl/index.php?page=gettingstarted](https://www.mining-dutch.nl/index.php?page=gettingstarted)
