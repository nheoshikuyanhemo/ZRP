// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ZorgRp is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    uint256 public normalFee = 10;     // 0.1%
    uint256 public sniperFee = 5000;   // 50%
    uint256 public launchBlock;
    bool public antiSniperEnabled = true;

    address public feeReceiver;
    address public liquidityWallet;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isDexRouter;

    // Router Constants
    address public constant MAVERICK_ROUTER = 0x816FA4266396b4a99390106617eE7bA9104018Fe;
    address public constant UNIVERSAL_ROUTER = 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B;

    constructor() ERC20("Zorg Rp", "ZRP") {
        _mint(msg.sender, INITIAL_SUPPLY);
        feeReceiver = msg.sender;
        liquidityWallet = msg.sender;
        launchBlock = block.number;

        // Set routers
        isDexRouter[MAVERICK_ROUTER] = true;
        isDexRouter[UNIVERSAL_ROUTER] = true;

        // Exclude owner
        isExcludedFromFee[msg.sender] = true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        bool takeFee = false;

        if (isDexRouter[sender] || isDexRouter[recipient]) {
            takeFee = true;
        }

        uint256 feeAmount = 0;

        if (takeFee && !(isExcludedFromFee[sender] || isExcludedFromFee[recipient])) {
            if (antiSniperEnabled && block.number <= launchBlock + 5) {
                feeAmount = (amount * sniperFee) / 10000;
            } else {
                feeAmount = (amount * normalFee) / 10000;
            }
        }

        uint256 transferAmount = amount - feeAmount;
        if (feeAmount > 0) {
            super._transfer(sender, feeReceiver, feeAmount);
        }
        super._transfer(sender, recipient, transferAmount);
    }

    // Admin controls
    function setRouter(address router, bool status) external onlyOwner {
        isDexRouter[router] = status;
    }

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

    // Rescue ETH
    function rescueETH(address payable to) external onlyOwner {
        to.transfer(address(this).balance);
    }

    // Simple reward mechanism
    address[] public holders;
    mapping(address => bool) public added;

    function distributeRewards() external payable onlyOwner {
        for (uint i = 0; i < holders.length; i++) {
            address user = holders[i];
            uint256 reward = (msg.value * balanceOf(user)) / totalSupply();
            payable(user).transfer(reward);
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        if (amount > 0 && !added[to]) {
            holders.push(to);
            added[to] = true;
        }
    }

    receive() external payable {}
}
