// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

error unAuthorized();

contract TokenFun is ERC20 {
    uint8 public constant DECIMALS = 18;

    uint256 public totalRaised;
    uint256 public constant SCALE = 1e18;

    // Bonding curve parameters
    uint256 public basePrice;
    uint256 public priceMultiplier;
    uint256 public initialSupply;

    // Fee settings
    uint256 public constant FEE_DENOMINATOR = 100;
    uint256 public constant DEV_FEE = 1; // 1%

    address public owner;
    address public treasury;

    struct TokenDetails {
        string _name;
        string _symbol;
    }

    mapping(address => TokenDetails[]) public tokenDetails;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event TokensSold(address indexed seller, uint256 amount, uint256 proceeds);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event TreasuryUpdated(address indexed newTreasury);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _priceMultiplier,
        address _treasury
    ) payable ERC20(_name, _symbol) {
        require(msg.value > 0, "Initial ETH required");

        initialSupply = _initialSupply;
        priceMultiplier = _priceMultiplier;
        treasury = _treasury;
        owner = msg.sender;
        basePrice = msg.value / _initialSupply;

        _mint(address(this), _initialSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function getCurrentPrice() public view returns (uint256) {
        return basePrice + ((priceMultiplier * totalSupply()) / SCALE);
    }

    function calculatePurchaseAmount(uint256 ethAmount) public view returns (uint256) {
        uint256 price = getCurrentPrice();
        return (SCALE * ethAmount) / price;
    }

    function buy() external payable {
        require(msg.value > 0, "Must send CORE");

        uint256 fee = (msg.value * DEV_FEE) / FEE_DENOMINATOR;
        uint256 purchaseValue = msg.value - fee;

        uint256 tokens = calculatePurchaseAmount(purchaseValue);
        require(tokens > 0, "Token amount too small");

        payable(treasury).transfer(fee);
        _transfer(address(this), msg.sender, tokens);

        totalRaised += msg.value;
        emit TokensPurchased(msg.sender, tokens, msg.value);
    }

    function sell(uint256 amount) external {
        if (amount <= 0) revert unAuthorized();
        require(balanceOf(msg.sender) >= amount, "Not enough balance");

        uint256 price = getCurrentPrice();
        uint256 ethValue = (amount * price) / SCALE;

        uint256 fee = (ethValue * DEV_FEE) / FEE_DENOMINATOR;
        uint256 proceeds = ethValue - fee;

        require(address(this).balance >= proceeds, "Contract has insufficient CORE");

        _transfer(msg.sender, address(this), amount);
        payable(treasury).transfer(fee);
        payable(msg.sender).transfer(proceeds);

        emit TokensSold(msg.sender, amount, proceeds);
    }

    function CreateToken(string memory _name, string memory _symbol) external {
        tokenDetails[msg.sender].push(TokenDetails(_name, _symbol));
    }

    function getTokenDetails(address user) external view returns (TokenDetails[] memory) {
        return tokenDetails[user];
    }

    // === Admin functions ===
    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert unAuthorized();
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function rescueEth() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
