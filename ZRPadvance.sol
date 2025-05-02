// SPDX-License-Identifier: MIT pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; import "@openzeppelin/contracts/access/Ownable.sol"; import "@openzeppelin/contracts/security/Pausable.sol"; import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IWrappedNative { function deposit() external payable; function transfer(address to, uint256 value) external returns (bool); }

contract ZorgRpAdvanced is ERC20, Ownable, Pausable { using EnumerableSet for EnumerableSet.AddressSet;

uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

uint256 public baseFee = 10;       // 0.1%
uint256 public sniperFee = 5000;   // 50%
uint256 public launchBlock;
bool public antiSniperEnabled = true;
uint256 public sniperBlockLimit = 5;

address public feeReceiver;
address public wrappedNative;

mapping(address => bool) public isExcludedFromFee;
mapping(address => bool) public isBlacklisted;
mapping(address => bool) public isDexRouter;

EnumerableSet.AddressSet private holders;

event FeeTaken(address indexed from, uint256 amount);
event RewardsDistributed(uint256 total);
event Rescue(address indexed to, uint256 amount);
event Blacklisted(address indexed user, bool status);
event RouterUpdated(address indexed router, bool status);

modifier onlyNonBlacklisted(address account) {
    require(!isBlacklisted[account], "Blacklisted");
    _;
}

constructor(address _wrappedNative) ERC20("Zorg Rp", "ZRP") {
    _mint(msg.sender, INITIAL_SUPPLY);
    feeReceiver = msg.sender;
    wrappedNative = _wrappedNative;
    launchBlock = block.number;
    isExcludedFromFee[msg.sender] = true;
}

function _transfer(address sender, address recipient, uint256 amount) internal override onlyNonBlacklisted(sender) onlyNonBlacklisted(recipient) {
    require(!paused(), "Token transfers paused");

    uint256 feeAmount = 0;
    bool takeFee = isDexRouter[sender] || isDexRouter[recipient];

    if (takeFee && !(isExcludedFromFee[sender] || isExcludedFromFee[recipient])) {
        if (antiSniperEnabled && block.number <= launchBlock + sniperBlockLimit) {
            feeAmount = (amount * sniperFee) / 10000;
        } else {
            feeAmount = (amount * baseFee) / 10000;
        }
        super._transfer(sender, feeReceiver, feeAmount);
        emit FeeTaken(sender, feeAmount);
    }

    super._transfer(sender, recipient, amount - feeAmount);

    if (balanceOf(recipient) > 0) {
        holders.add(recipient);
    }
}

function distributeRewards() external payable onlyOwner {
    require(msg.value > 0, "No ETH sent");
    IWrappedNative(wrappedNative).deposit{value: msg.value}();
    uint256 total = totalSupply();

    for (uint256 i = 0; i < holders.length(); i++) {
        address holder = holders.at(i);
        uint256 amount = (msg.value * balanceOf(holder)) / total;
        IWrappedNative(wrappedNative).transfer(holder, amount);
    }
    emit RewardsDistributed(msg.value);
}

function rescueETH(address payable to) external onlyOwner {
    uint256 bal = address(this).balance;
    require(bal > 0, "No ETH");
    to.transfer(bal);
    emit Rescue(to, bal);
}

// Admin functions
function blacklist(address user, bool status) external onlyOwner {
    isBlacklisted[user] = status;
    emit Blacklisted(user, status);
}

function setRouter(address router, bool status) external onlyOwner {
    isDexRouter[router] = status;
    emit RouterUpdated(router, status);
}

function setBaseFee(uint256 _fee) external onlyOwner {
    require(_fee <= 100, "Max 1%");
    baseFee = _fee;
}

function setSniperFee(uint256 _fee) external onlyOwner {
    require(_fee <= 10000, "Max 100%");
    sniperFee = _fee;
}

function toggleAntiSniper(bool status) external onlyOwner {
    antiSniperEnabled = status;
}

function pause() external onlyOwner {
    _pause();
}

function unpause() external onlyOwner {
    _unpause();
}

receive() external payable {}

}

