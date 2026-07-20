-- query 19: flag wallets that sent OR received a RECEIPT TOKEN (aToken/cToken) by direct
-- wallet-to-wallet transfer before the shock. Such transfers are NOT captured by the
-- protocol supply/withdraw events, so event-based balances can be distorted for these wallets.
-- Excluding them gives a "clean" robustness sample for size / tenure / participation.
--
-- Receipt-token contracts (Ethereum):
--   Aave V2  aUSDC  = 0xBcca60bB61934080951369a648Fb03DF4F96263C
--   Aave V3  aEthUSDC = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c
--   Comp V2  cUSDC  = 0x39AA39c021dfbaE8faC545936693aC917d5E7563
--   Comp V3  cUSDCv3= 0xc3d688B66703497DAA19211EEdff47f25384cdc3   (Comet base position; the
--            receipt is the account's base balance, transferred via Comet's own Transfer event)
--
-- We use the ERC-20 Transfer table for each token and keep only pure wallet<->wallet moves:
--   exclude mint/burn (from/to = 0x0) and exclude transfers to/from the lending pool / token
--   contract itself (those correspond to supply/withdraw, already captured).
-- Output: owner, market, role ('sender'/'receiver')  -> one row per (wallet, market, role) before t0.
-- Merge in Python: any wallet appearing here (either role) is "transfer-touched" and dropped in the
-- clean-sample robustness. Run -> export FULL -> save as data/receipt_transfers.csv -> upload.

WITH t AS (
  -- Aave V2 aUSDC
  SELECT "from" AS sender, to AS receiver, 'aave_v2' AS market, evt_block_time AS t
  FROM erc20_ethereum.evt_Transfer
  WHERE contract_address = 0xBcca60bB61934080951369a648Fb03DF4F96263C
  UNION ALL
  -- Aave V3 aEthUSDC
  SELECT "from", to, 'aave_v3', evt_block_time
  FROM erc20_ethereum.evt_Transfer
  WHERE contract_address = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c
  UNION ALL
  -- Compound V2 cUSDC
  SELECT "from", to, 'compound_v2', evt_block_time
  FROM erc20_ethereum.evt_Transfer
  WHERE contract_address = 0x39AA39c021dfbaE8faC545936693aC917d5E7563
  UNION ALL
  -- Compound V3 cUSDCv3 base-position transfers
  -- NOTE: if this leg returns nothing, the Comet base Transfer is not in erc20_ethereum.evt_Transfer;
  -- replace this SELECT with the decoded table:
  --   SELECT "from", to, ''compound_v3'', evt_block_time FROM compound_v3_ethereum.cusdcv3_evt_transfer
  SELECT "from", to, 'compound_v3', evt_block_time
  FROM erc20_ethereum.evt_Transfer
  WHERE contract_address = 0xc3d688B66703497DAA19211EEdff47f25384cdc3
),
pure AS (   -- keep only wallet<->wallet transfers before t0 (exclude mint/burn and pool/contract legs)
  SELECT sender, receiver, market FROM t
  WHERE t < TIMESTAMP '2023-03-09'
    AND sender   NOT IN (0x0000000000000000000000000000000000000000)
    AND receiver NOT IN (0x0000000000000000000000000000000000000000)
    -- exclude legs that are the receipt-token contract / pool itself (supply/withdraw plumbing)
    AND sender   NOT IN (0xBcca60bB61934080951369a648Fb03DF4F96263C,0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c,
                         0x39AA39c021dfbaE8faC545936693aC917d5E7563,0xc3d688B66703497DAA19211EEdff47f25384cdc3,
                         0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9,0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2)
    AND receiver NOT IN (0xBcca60bB61934080951369a648Fb03DF4F96263C,0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c,
                         0x39AA39c021dfbaE8faC545936693aC917d5E7563,0xc3d688B66703497DAA19211EEdff47f25384cdc3,
                         0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9,0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2)
)
SELECT sender   AS owner, market, 'sender'   AS role FROM pure GROUP BY sender, market
UNION
SELECT receiver AS owner, market, 'receiver' AS role FROM pure GROUP BY receiver, market
