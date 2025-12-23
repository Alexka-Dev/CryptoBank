# CryptoBank
CryptoBank is a smart contract treasury system designed to manage both Ether and ERC-20 tokens (specifically optimized for RealEstateToken). It provides a secure layer for decentralized finance (DeFi) operations by implementing:

## Overview

CryptoBank is designed for decentralized financial ecosystems requiring robust treasury management. Its architecture is suitable for any use case requiring:

- **Dual Asset Management:** Support for native ETH and any standard ERC-20 token.
- **Dynamic Limits:** User-level max balance and time-gated daily withdrawal caps.
- **Revenue Generation:** Integrated fee calculation for every withdrawal (ETH and Tokens).
- **Security Control:** Emergency pause functionality and address blacklisting.
- **Admin Governance:** Fine-grained control over global variables and token-specific parameters.

---

## Prerequisites & Dependencies

To test the token-specific functionalities, the **RealEstateToken (RET)** contract (or any ERC-20) must be deployed beforehand. 

CryptoBank utilizes the `IERC20` interface to interact with external tokens. It follows the standard **Approve-then-Transfer** pattern to ensure security during deposits.

---

## Remix Testing Guide

Follow these steps to test the contract logic within the Remix IDE environment:

### 1. Deployment Phase
1. **Deploy Token:** Deploy the `RealEstateToken.sol` first. Copy the contract address once deployed.
2. **Deploy Bank:** Select `CryptoBank.sol` and provide the following constructor arguments:
   - `maxBalance_`: The maximum balance a user can hold (e.g., `10 ether`).
   - `admin_`: Your wallet address.

### 2. Ether Operations
- **Deposit:** Set the `Value` field in Remix (e.g., 1 Ether) and trigger `depositEther()`.
- **Withdraw:** Call `withdrawEther(amount)`. Note that a **0.01% fee** is automatically deducted and sent to the `totalFeesCollected` pool.

### 3. Token Operations (Using RET)
- **Step 1 (Approve):** Navigate to the deployed `RealEstateToken` contract. Call `approve(CryptoBank_Address, amount)`.
- **Step 2 (Deposit):** In `CryptoBank`, call `depositToken(RET_Address, amount)`.
- **Step 3 (Setup):** As the **Admin**, you must call `setTokenDailyLimit` for the RET address. Optionally, call `setTokenFeeRate` (in Basis Points).
- **Step 4 (Withdraw):** Call `withdrawToken(RET_Address, amount)`.

---

## Administrative Features

| Function | Action | Description |
| :--- | :--- | :--- |
| `pauseContract` | Emergency | Disables deposits and withdrawals for all users. |
| `AddToBlacklist` | Security | Prevents a specific address from interacting with the bank. |
| `withdrawFees` | Revenue | Transfers all accumulated ETH fees to the Admin wallet. |
| `setTokenFeeRate` | Config | Sets the commission for a specific token (e.g., 100 BPS = 1%). |

---

## Technical Specifications

- **Fee Calculation:** Token fees are handled via **Basis Points (BPS)**. 
  - $1 \text{ BPS} = 0.01\%$
  - $100 \text{ BPS} = 1\%$
- **Withdrawal Reset:** Daily limits reset based on a 24-hour window from the user's `lastWithdrawalTimestamp`.
- **Internal Security:** Employs the "Checks-Effects-Interactions" pattern to prevent common vulnerabilities.

---

## License
This project is licensed under the **MIT License**.
