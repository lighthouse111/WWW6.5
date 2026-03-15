// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDepositBox {
    function deposit(string calldata secret) external;
    function reveal() external view returns (string memory);
    function boxType() external pure returns (string memory);
}

abstract contract BaseDepositBox is IDepositBox {
    address public owner;
    string internal _secret;
    string public boxName;

    event SecretStored(address indexed user);

    constructor(address _owner, string memory _name) {
        owner = _owner;
        boxName = _name;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the box owner");
        _;
    }

    function deposit(string calldata secret) external virtual onlyOwner {
        _secret = secret;
        emit SecretStored(msg.sender);
    }

    function rename(string calldata newName) external onlyOwner {
        boxName = newName;
    }

    function reveal() external view virtual returns (string memory);
    function boxType() external pure virtual returns (string memory);
}

contract BasicDepositBox is BaseDepositBox {
    constructor(address _owner, string memory _name) BaseDepositBox(_owner, _name) {}

    function reveal() external view override onlyOwner returns (string memory) {
        return _secret;
    }

    function boxType() external pure override returns (string memory) {
        return "Basic";
    }
}

contract PremiumDepositBox is BaseDepositBox {
    string public metadata;

    constructor(address _owner, string memory _name, string memory _metadata) 
        BaseDepositBox(_owner, _name) 
    {
        metadata = _metadata;
    }

    function reveal() external view override onlyOwner returns (string memory) {
        return string(abi.encodePacked("Premium Secret: ", _secret, " | Info: ", metadata));
    }

    function boxType() external pure override returns (string memory) {
        return "Premium";
    }
}


contract TimeLockedDepositBox is BaseDepositBox {
    uint256 public unlockTime;

    constructor(address _owner, string memory _name, uint256 _duration) 
        BaseDepositBox(_owner, _name) 
    {
        unlockTime = block.timestamp + _duration;
    }

    function reveal() external view override onlyOwner returns (string memory) {
        require(block.timestamp >= unlockTime, "Vault is still locked!");
        return _secret;
    }

    function boxType() external pure override returns (string memory) {
        return "TimeLocked";
    }
}


contract VaultManager {

    mapping(address => address[]) public userVaults;
    
    event VaultCreated(address indexed owner, address vaultAddress, string vaultType);


    function createBasicVault(string calldata name) external returns (address) {
        BasicDepositBox newVault = new BasicDepositBox(msg.sender, name);
        userVaults[msg.sender].push(address(newVault));
        emit VaultCreated(msg.sender, address(newVault), "Basic");
        return address(newVault);
    }


    function createPremiumVault(string calldata name, string calldata metadata) external returns (address) {
        PremiumDepositBox newVault = new PremiumDepositBox(msg.sender, name, metadata);
        userVaults[msg.sender].push(address(newVault));
        emit VaultCreated(msg.sender, address(newVault), "Premium");
        return address(newVault);
    }


    function createTimeLockedVault(string calldata name, uint256 duration) external returns (address) {
        TimeLockedDepositBox newVault = new TimeLockedDepositBox(msg.sender, name, duration);
        userVaults[msg.sender].push(address(newVault));
        emit VaultCreated(msg.sender, address(newVault), "TimeLocked");
        return address(newVault);
    }

    function getMyVaults() external view returns (address[] memory) {
        return userVaults[msg.sender];
    }
}