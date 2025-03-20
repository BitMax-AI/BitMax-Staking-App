// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SYToken.sol";

contract YieldTokenization is Ownable {
    SYToken public syToken;
    
    // PT and YT tokens
    mapping(uint256 => address) public ptTokens; // maturity timestamp -> token address
    mapping(uint256 => address) public ytTokens; // maturity timestamp -> token address
    
    // Available maturity dates
    uint256[] public maturities;
    
    event TokensSplit(address indexed user, uint256 amount, uint256 maturity);
    event TokensRedeemed(address indexed user, uint256 amount, uint256 maturity);
    
    constructor(address _syToken) Ownable(msg.sender) {
        syToken = SYToken(_syToken);
        
        // Create 30-day maturity
        createMaturity(block.timestamp + 30 days);
    }
    
    // Create new maturity option
    function createMaturity(uint256 maturityTimestamp) public onlyOwner {
        require(maturityTimestamp > block.timestamp, "Maturity must be in future");
        
        // Deploy new PT token
        PTToken pt = new PTToken("PT syCORE", "PT-syCORE", maturityTimestamp);
        
        // Deploy new YT token
        YTToken yt = new YTToken("YT syCORE", "YT-syCORE", maturityTimestamp);
        
        // Store token addresses
        ptTokens[maturityTimestamp] = address(pt);
        ytTokens[maturityTimestamp] = address(yt);
        maturities.push(maturityTimestamp);
    }
    
    // Split SY tokens into PT and YT
    function split(uint256 amount, uint256 maturity) external {
        require(ptTokens[maturity] != address(0), "Invalid maturity");
        require(syToken.balanceOf(msg.sender) >= amount, "Insufficient SY balance");
        
        // Transfer SY tokens to this contract
        syToken.transferFrom(msg.sender, address(this), amount);
        
        // Mint PT and YT tokens to user
        PTToken(ptTokens[maturity]).mint(msg.sender, amount);
        YTToken(ytTokens[maturity]).mint(msg.sender, amount);
        
        emit TokensSplit(msg.sender, amount, maturity);
    }
    
    // Redeem PT tokens at maturity
    function redeem(uint256 amount, uint256 maturity) external {
        require(block.timestamp >= maturity, "Not yet mature");
        require(ptTokens[maturity] != address(0), "Invalid maturity");
        
        PTToken pt = PTToken(ptTokens[maturity]);
        require(pt.balanceOf(msg.sender) >= amount, "Insufficient PT balance");
        
        // Burn PT tokens
        pt.burnFrom(msg.sender, amount);
        
        // Transfer SY tokens back to user
        syToken.transfer(msg.sender, amount);
        
        emit TokensRedeemed(msg.sender, amount, maturity);
    }
    
    // Get available maturities
    function getMaturities() external view returns (uint256[] memory) {
        return maturities;
    }
}

// Principal Token
contract PTToken is ERC20, Ownable {
    uint256 public maturity;
    
    constructor(string memory name, string memory symbol, uint256 _maturity) 
        ERC20(name, symbol)
        Ownable(msg.sender) 
    {
        maturity = _maturity;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function burnFrom(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}

// Yield Token
contract YTToken is ERC20, Ownable {
    uint256 public maturity;
    
    constructor(string memory name, string memory symbol, uint256 _maturity) 
        ERC20(name, symbol)
        Ownable(msg.sender) 
    {
        maturity = _maturity;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function burnFrom(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}