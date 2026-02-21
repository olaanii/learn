// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TestToken
 * @notice Simple ERC-20 test token for Diaspora Equb on Creditcoin Testnet.
 *         Deploys as TestUSDC (6 decimals) or TestUSDT (6 decimals).
 *         The deployer can mint freely for testing purposes.
 */
contract TestToken {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "TestToken: caller is not the owner");
        _;
    }

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
    }

    /**
     * @notice Mint tokens to any address. Only the deployer can call this.
     *         Use this to give test tokens to testers.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice Public faucet: anyone can mint up to 10,000 tokens to themselves.
     *         Useful for testnet self-service.
     */
    function faucet(uint256 amount) external {
        require(amount <= 10_000 * (10 ** decimals), "TestToken: faucet max 10,000 tokens");
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "TestToken: insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "TestToken: insufficient balance");
        require(allowance[from][msg.sender] >= amount, "TestToken: insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
