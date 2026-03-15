// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MyToken is ERC20, Ownable {
    bool public transfersEnabled = false;

    constructor(
        string memory name, 
        string memory symbol, 
        uint256 totalUintSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {

        _mint(msg.sender, totalUintSupply * 10 ** decimals());
    }

    function enableTransfers() external onlyOwner {
        transfersEnabled = true;
    }


    function _update(address from, address to, uint256 value) internal virtual override {

        if (!transfersEnabled && from != address(0) && from != owner()) {
            revert("Transfers are currently locked");
        }
        super._update(from, to, value);
    }
}


contract TokenPresale is Ownable {
    MyToken public token;
    uint256 public rate;          
    uint256 public minPurchase;   
    uint256 public maxPurchase;   
    uint256 public startTime;     
    uint256 public endTime;       
    bool public isFinalized = false;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event PresaleFinalized(uint256 ethAmount, uint256 remainingTokens);

    constructor(
        address payable _tokenAddress,
        uint256 _rate,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _startTime,
        uint256 _endTime
    ) Ownable(msg.sender) {
        require(_startTime < _endTime, "Start must be before end");
        require(_tokenAddress != address(0), "Invalid token address");
        
        token = MyToken(_tokenAddress);
        rate = _rate;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        startTime = _startTime;
        endTime = _endTime;
    }


    receive() external payable {
        buyTokens();
    }


    function buyTokens() public payable {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Presale not active");
        require(msg.value >= minPurchase, "Purchase below minimum");
        require(msg.value <= maxPurchase, "Purchase exceeds maximum");
        require(!isFinalized, "Presale already finalized");

        uint256 tokenAmount = msg.value * rate;
        
     
        require(token.balanceOf(address(this)) >= tokenAmount, "Contract has insufficient tokens");


        token.transfer(msg.sender, tokenAmount);

        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }


    function finalize() external onlyOwner {

        require(block.timestamp > endTime || token.balanceOf(address(this)) == 0, "Presale condition not met");
        require(!isFinalized, "Already finalized");

        isFinalized = true;
        uint256 ethBalance = address(this).balance;
        uint256 remainingTokens = token.balanceOf(address(this));


        (bool success, ) = payable(owner()).call{value: ethBalance}("");
        require(success, "ETH withdrawal failed");


        if (remainingTokens > 0) {
            token.transfer(owner(), remainingTokens);
        }

        emit PresaleFinalized(ethBalance, remainingTokens);
    }

 
    function getAvailableTokens() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
}