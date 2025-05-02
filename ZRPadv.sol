// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ZorgRpAdvanced {
    string public name = "Zorg Rp";
    string public symbol = "ZRP";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    uint256 public baseFee = 10;        // 0.1%
    uint256 public sniperFee = 5000;    // 50%
    uint256 public launchBlock;
    bool public antiSniperEnabled = true;
    uint256 public sniperBlockLimit = 5;

    address public owner;
    address public feeReceiver;
    address public wrappedNative;
    address public liquidityPool;
    bool public paused;
    uint256 public liquidityThreshold = 1000 * 10**18;
    uint256 public cooldownTime = 30;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isDexRouter;
    mapping(address => uint256) public lastTransferTime;

    address[] public holders;
    mapping(address => bool) public isHolder;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyNonBlacklisted(address account) {
        require(!isBlacklisted[account], "Blacklisted");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    constructor(address _wrappedNative) {
        owner = msg.sender;
        feeReceiver = msg.sender;
        wrappedNative = _wrappedNative;
        launchBlock = block.number;

        totalSupply = 1_000_000_000 * 10 ** decimals;
        balanceOf[msg.sender] = totalSupply;
        isExcludedFromFee[msg.sender] = true;
        isHolder[msg.sender] = true;
        holders.push(msg.sender);

        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 value)
        public
        onlyNonBlacklisted(msg.sender)
        onlyNonBlacklisted(to)
        whenNotPaused
        returns (bool)
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
        public
        onlyNonBlacklisted(from)
        onlyNonBlacklisted(to)
        whenNotPaused
        returns (bool)
    {
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(balanceOf[sender] >= amount, "Balance too low");
        require(block.timestamp >= lastTransferTime[sender] + cooldownTime, "Cooldown active");

        lastTransferTime[sender] = block.timestamp;

        uint256 feeAmount = 0;
        bool takeFee = isDexRouter[sender] || isDexRouter[recipient];

        if (takeFee && !(isExcludedFromFee[sender] || isExcludedFromFee[recipient])) {
            if (antiSniperEnabled && block.number <= launchBlock + sniperBlockLimit) {
                feeAmount = (amount * sniperFee) / 10000;
            } else {
                feeAmount = (amount * baseFee) / 10000;
            }
            balanceOf[feeReceiver] += feeAmount;
            emit Transfer(sender, feeReceiver, feeAmount);
        }

        balanceOf[sender] -= amount;
        balanceOf[recipient] += (amount - feeAmount);
        emit Transfer(sender, recipient, amount - feeAmount);

        if (!isHolder[recipient]) {
            holders.push(recipient);
            isHolder[recipient] = true;
        }

        if (
            balanceOf[address(this)] >= liquidityThreshold &&
            sender != liquidityPool &&
            recipient != liquidityPool
        ) {
            _addLiquidity(liquidityThreshold);
        }
    }

    function _addLiquidity(uint256 tokenAmount) private {
        balanceOf[address(this)] -= tokenAmount;
        balanceOf[liquidityPool] += tokenAmount;
        emit Transfer(address(this), liquidityPool, tokenAmount);
        // Optionally: sync with DEX pair here
    }

    function distributeRewards() public payable onlyOwner {
        require(msg.value > 0, "No ETH sent");
        uint256 total = totalSupply;

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 reward = (msg.value * balanceOf[holder]) / total;
            payable(holder).transfer(reward);
        }
    }

    function rescueETH(address payable to) public onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "No ETH");
        to.transfer(bal);
    }

    // Admin functions
    function blacklist(address user, bool status) public onlyOwner {
        isBlacklisted[user] = status;
    }

    function setRouter(address router, bool status) public onlyOwner {
        isDexRouter[router] = status;
    }

    function setBaseFee(uint256 _fee) public onlyOwner {
        require(_fee <= 100, "Max 1%");
        baseFee = _fee;
    }

    function setSniperFee(uint256 _fee) public onlyOwner {
        require(_fee <= 10000, "Max 100%");
        sniperFee = _fee;
    }

    function toggleAntiSniper(bool status) public onlyOwner {
        antiSniperEnabled = status;
    }

    function pause() public onlyOwner {
        paused = true;
    }

    function unpause() public onlyOwner {
        paused = false;
    }

    function setLiquidityPool(address _pool) public onlyOwner {
        liquidityPool = _pool;
    }

    function setCooldown(uint256 seconds_) public onlyOwner {
        cooldownTime = seconds_;
    }

    receive() external payable {}
}
