-- Welfare: minute-level USDC price across the depeg trough (for realized-loss calculation).
-- Output columns: ts, price
SELECT date_trunc('minute', minute) AS ts, price
FROM prices.usd
WHERE blockchain = 'ethereum' AND contract_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  AND minute >= TIMESTAMP '2023-03-10' AND minute < TIMESTAMP '2023-03-14'
ORDER BY ts
