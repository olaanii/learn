// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CollateralVault {
    mapping(address => uint256) private collateralBalances;
    mapping(address => uint256) private lockedBalances;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralSlashed(address indexed user, uint256 amount);
    event CollateralReleased(address indexed user, uint256 amount);
    event CollateralLocked(address indexed user, uint256 amount);
    event CollateralCompensated(address indexed poolTreasury, address indexed user, uint256 amount);

    function depositCollateral() external payable {
        require(msg.value > 0, "invalid amount");
        collateralBalances[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    function slashCollateral(address user, uint256 amount) external {
        uint256 balance = collateralBalances[user];
        uint256 slashAmount = amount > balance ? balance : amount;
        collateralBalances[user] -= slashAmount;
        emit CollateralSlashed(user, slashAmount);
    }

    function lockCollateral(address user, uint256 amount) external {
        uint256 balance = collateralBalances[user];
        require(amount <= balance, "insufficient collateral");
        collateralBalances[user] -= amount;
        lockedBalances[user] += amount;
        emit CollateralLocked(user, amount);
    }

    function slashLocked(address user, uint256 amount) external {
        uint256 locked = lockedBalances[user];
        uint256 slashAmount = amount > locked ? locked : amount;
        lockedBalances[user] -= slashAmount;
        emit CollateralSlashed(user, slashAmount);
    }

    function compensatePool(address poolTreasury, address user, uint256 amount) external {
        uint256 locked = lockedBalances[user];
        uint256 compensation = amount > locked ? locked : amount;
        lockedBalances[user] -= compensation;
        emit CollateralCompensated(poolTreasury, user, compensation);
    }

    function releaseCollateral(address user, uint256 amount) external {
        uint256 balance = collateralBalances[user];
        require(amount <= balance, "insufficient collateral");
        collateralBalances[user] -= amount;
        payable(user).transfer(amount);
        emit CollateralReleased(user, amount);
    }

    function collateralOf(address user) external view returns (uint256) {
        return collateralBalances[user];
    }

    function lockedOf(address user) external view returns (uint256) {
        return lockedBalances[user];
    }
}
