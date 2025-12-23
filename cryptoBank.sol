// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IERC20 {
    function transfer(address to, uint amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint amount
    ) external returns (bool);
}

contract CryptoBank {
    // _____________________________________________
    // Global Variables
    // _____________________________________________
    uint public maxBalance;
    address public admin;
    uint public totalFeesCollected;
    uint256 public dailyWithdrawLimit = 4 ether;
    bool public paused;

    // _____________________________________________
    // Mappings
    // _____________________________________________
    mapping(address => uint256) public userBalance;
    mapping(address => bool) public isBlacklisted;
    mapping(address => uint256) public withdrawnLast24h;
    mapping(address => uint256) public lastWithdrawalTimestamp;

    // Token balances: token => user => balance
    mapping(address => mapping(address => uint256)) public tokenBalance;

    // Daily limits for tokens: token => user => amount withdrawn in the last 24 hours
    mapping(address => mapping(address => uint256))
        public tokenWithdrawnLast24h;
    mapping(address => mapping(address => uint256))
        public tokenLastWithdrawalTimestamp;

    // _________________________________________________
    // Token-specific fee & limits
    // _________________________________________________

    mapping(address => uint256) public tokenFeeBps; // fee per token in basis points (1 = 0.01%)
    mapping(address => uint256) public tokenFeesCollected; // fees accumulated per token
    mapping(address => uint256) public tokenDailyLimit; // daily limit per token

    // _________________________________________________
    // Events
    // _________________________________________________
    event EtherDeposit(address user_, uint etherAmount_);
    event EtherWithdraw(
        address indexed user_,
        uint amountRequested_,
        uint fee_,
        uint amountSentToUser_,
        uint finalBalance_
    );
    event TokenDeposit(
        address indexed user_,
        address indexed token_,
        uint amount_
    );
    event TokenWithdraw(
        address indexed user_,
        address indexed token_,
        uint amountRequested_,
        uint fee_,
        uint amountSentToUser_,
        uint finalTokenBalance_
    );
    event BlacklistUpdated(address indexed user_, bool status);
    event FeesWithdrawn(address indexed admin_, uint amount_);
    event TokenFeesWithdrawn(
        address indexed admin_,
        address indexed token_,
        uint amount_
    );
    event Paused(address indexed admin_);
    event Unpaused(address indexed admin_);
    event TokenFeeRateUpdated(address indexed token_, uint256 feeBps_);
    event TokenDailyLimitUpdated(address indexed token_, uint256 limit_);

    // _________________________________________________
    // Modifiers
    // _________________________________________________
    modifier onlyAdmin() {
        require(
            msg.sender == admin,
            "Not allowed to modify, you are not Admin."
        );
        _;
    }

    modifier notBlacklisted() {
        require(!isBlacklisted[msg.sender], "Your address is Blacklisted");
        _;
    }

    modifier notPausedContract() {
        require(!paused, "Contract paused for security.");
        _;
    }

    // _________________________________________________
    // Constructor
    // _________________________________________________
    constructor(uint maxBalance_, address admin_) {
        maxBalance = maxBalance_;
        admin = admin_;
    }

    // _________________________________________________
    // Deposit
    // _________________________________________________
    function depositEther() external payable notBlacklisted notPausedContract {
        require(
            userBalance[msg.sender] + msg.value <= maxBalance,
            "Balance reached."
        );
        userBalance[msg.sender] += msg.value;
        emit EtherDeposit(msg.sender, msg.value);
    }

    // _______________________________________________
    // Withdraw (with daily limit + fee)
    // ________________________________________________
    function withdrawEther(
        uint256 amount_
    ) external notBlacklisted notPausedContract {
        require(amount_ <= userBalance[msg.sender], "Not enough Ether");

        // ____ DAILY WITHDRAW LIMIT MANAGEMENT _____
        if (block.timestamp >= lastWithdrawalTimestamp[msg.sender] + 24 hours) {
            withdrawnLast24h[msg.sender] = 0;
        }

        require(
            withdrawnLast24h[msg.sender] + amount_ <= dailyWithdrawLimit,
            "Daily withdraw limit exceeded"
        );

        withdrawnLast24h[msg.sender] += amount_;
        lastWithdrawalTimestamp[msg.sender] = block.timestamp;

        // --- FEE CALCULATION ---
        uint fee_ = calculateFee(amount_);
        uint amountUserReceives_ = amount_ - fee_;
        uint finalBalance_ = userBalance[msg.sender] - amount_;

        // --- EFFECTS ---
        userBalance[msg.sender] = finalBalance_;
        totalFeesCollected += fee_;

        // --- INTERACTION ---
        (bool success, ) = msg.sender.call{value: amountUserReceives_}("");
        require(success, "Transfer failed");

        emit EtherWithdraw(
            msg.sender,
            amount_,
            fee_,
            amountUserReceives_,
            finalBalance_
        );
    }

    // -------------------------------------------------
    // Deposit (TOKEN)
    // -------------------------------------------------
    function depositToken(
        address token_,
        uint amount_
    ) external notBlacklisted notPausedContract {
        require(amount_ > 0, "Amount must be greater than zero");

        bool success = IERC20(token_).transferFrom(
            msg.sender,
            address(this),
            amount_
        );
        require(success, "Token transfer failed");

        tokenBalance[token_][msg.sender] += amount_;

        emit TokenDeposit(msg.sender, token_, amount_);
    }

    // -------------------------------------------------
    // Withdraw (TOKEN with daily limit + fee per token)
    // -------------------------------------------------
    function withdrawToken(
        address token_,
        uint amount_
    ) external notBlacklisted notPausedContract {
        require(
            amount_ <= tokenBalance[token_][msg.sender],
            "Not enough token balance"
        );
        require(tokenDailyLimit[token_] > 0, "Token daily limit not set");

        // --- DAILY TOKEN WITHDRAW LIMIT MANAGEMENT ---
        if (
            block.timestamp >=
            tokenLastWithdrawalTimestamp[token_][msg.sender] + 24 hours
        ) {
            tokenWithdrawnLast24h[token_][msg.sender] = 0;
        }

        require(
            tokenWithdrawnLast24h[token_][msg.sender] + amount_ <=
                tokenDailyLimit[token_],
            "Daily token withdraw limit exceeded"
        );

        tokenWithdrawnLast24h[token_][msg.sender] += amount_;
        tokenLastWithdrawalTimestamp[token_][msg.sender] = block.timestamp;

        // --- FEE CALCULATION (TOKEN) ---
        uint256 feeBps_ = tokenFeeBps[token_]; // 0 si no se configuró
        uint fee_ = 0;
        if (feeBps_ > 0) {
            fee_ = (amount_ * feeBps_) / 10000;
        }

        uint amountUserReceives_ = amount_ - fee_;
        uint finalTokenBalance_ = tokenBalance[token_][msg.sender] - amount_;

        // --- EFFECTS ---
        tokenBalance[token_][msg.sender] = finalTokenBalance_;
        tokenFeesCollected[token_] += fee_;

        // --- INTERACTION ---
        bool success = IERC20(token_).transfer(msg.sender, amountUserReceives_);
        require(success, "Token transfer failed");

        emit TokenWithdraw(
            msg.sender,
            token_,
            amount_,
            fee_,
            amountUserReceives_,
            finalTokenBalance_
        );
    }

    // _________________________________________________
    // Admin: Modify maxBalance
    // _________________________________________________
    function modifyMaxBalance(uint newMaxBalance_) external onlyAdmin {
        maxBalance = newMaxBalance_;
    }

    // _________________________________________________
    // Admin: Modify daily withdraw limit
    // _________________________________________________
    function setDailyWithdrawLimit(uint256 newLimit_) external onlyAdmin {
        require(newLimit_ > 0, "Limit must be greater than zero");
        dailyWithdrawLimit = newLimit_;
    }

    // -------------------------------------------------
    // Admin: Set token daily withdraw limit
    // -------------------------------------------------
    function setTokenDailyLimit(
        address token_,
        uint256 newLimit_
    ) external onlyAdmin {
        require(newLimit_ > 0, "Limit must be greater than zero");
        tokenDailyLimit[token_] = newLimit_;
        emit TokenDailyLimitUpdated(token_, newLimit_);
    }

    // -------------------------------------------------
    // Admin: Set token fee rate (basis points)
    // 1 bps = 0.01%, 100 = 1%, 10 = 0.1%, etc.
    // -------------------------------------------------
    function setTokenFeeRate(
        address token_,
        uint256 feeBps_
    ) external onlyAdmin {
        require(feeBps_ <= 10000, "Fee too high");
        tokenFeeBps[token_] = feeBps_;
        emit TokenFeeRateUpdated(token_, feeBps_);
    }

    // _________________________________________________
    // Admin: Withdraw accumulated ETH fees
    // __________________________________________________
    function withdrawFees() external onlyAdmin notPausedContract {
        uint amount_ = totalFeesCollected;
        require(amount_ > 0, "No fees to withdraw");

        totalFeesCollected = 0;

        (bool success, ) = admin.call{value: amount_}("");
        require(success, "Fee withdrawal failed");

        emit FeesWithdrawn(admin, amount_);
    }

    // -------------------------------------------------
    // Admin: Withdraw token fees
    // -------------------------------------------------
    function withdrawTokenFees(
        address token_
    ) external onlyAdmin notPausedContract {
        uint amount_ = tokenFeesCollected[token_];
        require(amount_ > 0, "No token fees to withdraw");

        tokenFeesCollected[token_] = 0;

        bool success = IERC20(token_).transfer(admin, amount_);
        require(success, "Token fee withdrawal failed");

        emit TokenFeesWithdrawn(admin, token_, amount_);
    }

    //________________________________________________
    //ADMIN: Paused/unpause contract
    //________________________________________________
    function pauseContract() external onlyAdmin {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpauseContract() external onlyAdmin {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ________________________________________________
    // Fee Calculation
    // ________________________________________________
    function calculateFee(uint amount_) internal pure returns (uint) {
        return (amount_ * 1) / 10000; // 0.01%
    }

    // ________________________________________________
    // Blacklist
    // ________________________________________________
    function AddToBlacklist(address user_) external onlyAdmin {
        isBlacklisted[user_] = true;
        emit BlacklistUpdated(user_, true);
    }

    function removeFromBlackclist(address user_) external onlyAdmin {
        isBlacklisted[user_] = false;
        emit BlacklistUpdated(user_, false);
    }
}
