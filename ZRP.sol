// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ZorgRp is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    uint256 public normalFee = 10; // 0.1% (in basis points, i.e., 10 = 0.1%)
    uint256 public sniperFee = 5000; // 50%
    uint256 public launchBlock;
    bool public antiSniperEnabled = true;

    address public feeReceiver;
    address public liquidityWallet;
    mapping(address => bool) public isExcludedFromFee;

    constructor() ERC20("Zorg Rp", "ZRP") {
        _mint(msg.sender, INITIAL_SUPPLY);
        feeReceiver = msg.sender;
        liquidityWallet = msg.sender;
        launchBlock = block.number;
        isExcludedFromFee[msg.sender] = true;
    }

    // Core Transfer Override with Fees
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        if (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 feeAmount;
        if (antiSniperEnabled && block.number <= launchBlock + 5) {
            // Early blocks = sniper
            feeAmount = (amount * sniperFee) / 10000;
        } else {
            feeAmount = (amount * normalFee) / 10000;
        }

        uint256 transferAmount = amount - feeAmount;
        super._transfer(sender, feeReceiver, feeAmount); // send fee
        super._transfer(sender, recipient, transferAmount);
    }

    // Function to withdraw native coin sent to contract
    function rescueETH(address payable to) external onlyOwner {
        require(address(this).balance > 0, "No ETH to rescue");
        to.transfer(address(this).balance);
    }

    // Send wrapped native rewards to holders
    function distributeRewards() external payable onlyOwner {
        require(totalSupply() > 0, "No supply");
        for (uint256 i = 0; i < holders.length; i++) {
            address user = holders[i];
            uint256 balance = balanceOf(user);
            if (balance > 0) {
                uint256 reward = (msg.value * balance) / totalSupply();
                payable(user).transfer(reward);
            }
        }
    }

    // Manage holders list (simplified - not optimal for gas)
    address[] public holders;
    mapping(address => bool) public added;

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        if (amount > 0 && !added[to]) {
            holders.push(to);
            added[to] = true;
        }
    }

    // Admin functions to update fees, receiver, anti-sniper
    function setNormalFee(uint256 _fee) external onlyOwner {
        require(_fee <= 100, "Max 1%");
        normalFee = _fee;
    }

    function setSniperFee(uint256 _fee) external onlyOwner {
        require(_fee <= 10000, "Max 100%");
        sniperFee = _fee;
    }

    function setFeeReceiver(address _receiver) external onlyOwner {
        feeReceiver = _receiver;
    }

    function toggleAntiSniper(bool _status) external onlyOwner {
        antiSniperEnabled = _status;
    }

    receive() external payable {}
}
