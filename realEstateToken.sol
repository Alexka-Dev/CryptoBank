// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./calculator.sol";

contract realEstateToken is ERC20Capped, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    mapping(address => bool) public blacklist;
    bool public presaleActive = true;
    uint public presalePrice = 0.01 ether;

    calculator public calc;

    constructor(
        string memory name_,
        string memory symbol_,
        uint cap_,
        address calculatorAddress
    ) ERC20(name_, symbol_) ERC20Capped(cap_ * 1e18) {
        _mint(msg.sender, 1000 * 1e18);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        calc = calculator(calculatorAddress);
    }

    /* ---------------- CONTROL DE ACCESO -------------------*/

    function mint(address to, uint amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    /* ------------------- BLACKLIST -------------------------*/
    function addToBlacklist(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklist[account] = true;
    }

    function removeFromBlacklist(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklist[account] = false;
    }

    /* ----------------- INTERNAL FUNCTIONS ----------------- */
    //Verificacion de la Blacklist
    function _update(
        address from,
        address to,
        uint amount
    ) internal virtual override {
        require(!blacklist[from] && !blacklist[to], "Address blacklisted");
        super._update(from, to, amount);
    }

    /* --------------------- PRESALE ------------------------ */

    function buyPresale(uint tokenAmount) external payable {
        require(presaleActive, "Presale ended");
        require(msg.value >= tokenAmount * presalePrice, "Insuficient ETH");
        _mint(msg.sender, tokenAmount * 1e18);
    }

    function endPresale() external onlyRole(DEFAULT_ADMIN_ROLE) {
        presaleActive = false;
    }

    /* -------------------- AIRDROP ------------------------ */
    function airdrop(
        address[] calldata recipients,
        uint amount
    ) external onlyRole(MINTER_ROLE) {
        for (uint i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amount);
        }
    }
    /* --------------- CALCULATOR INTEGRATION -------------- */
    //Example: calculate platform commission and reward the user.

    function payListingFee(
        uint listingPrice,
        uint commissionPercentage
    ) external {
        calc.reset();
        calc.addition(listingPrice);
        uint commission = calc.percentage(commissionPercentage);

        _burn(msg.sender, commission);
        _mint(msg.sender, 5 * 1e18); // incentivo
    }

    //Example: Calculating the ROI of a real estate investment

    function calculateROI(
        uint investment,
        uint gainPercentage
    ) external returns (uint) {
        calc.reset();
        calc.addition(investment);
        uint roi = calc.percentage(gainPercentage);
        return roi;
    }
}
