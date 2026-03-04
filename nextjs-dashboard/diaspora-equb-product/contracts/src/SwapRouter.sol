// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20.sol";

/**
 * @title SwapRouter
 * @notice Constant-product AMM for CTC <-> ERC-20 token swaps.
 *         Each pool pairs native CTC with a single ERC-20 token.
 *         0.3% (30 bps) swap fee.
 */
contract SwapRouter {
    struct Pool {
        uint256 ctcReserve;
        uint256 tokenReserve;
        uint256 totalShares;
    }

    mapping(address => Pool) public pools;
    mapping(address => mapping(address => uint256)) public shares; // token -> provider -> shares

    event LiquidityAdded(
        address indexed provider,
        address indexed token,
        uint256 ctcAmount,
        uint256 tokenAmount,
        uint256 sharesMinted
    );

    event LiquidityRemoved(
        address indexed provider,
        address indexed token,
        uint256 ctcAmount,
        uint256 tokenAmount,
        uint256 sharesBurned
    );

    event Swap(
        address indexed user,
        address indexed token,
        bool ctcToToken,
        uint256 amountIn,
        uint256 amountOut
    );

    /**
     * @notice Add liquidity to a CTC/token pool.
     *         First provider sets the ratio. Subsequent providers must match.
     */
    function addLiquidity(address token) external payable returns (uint256 sharesMinted) {
        require(msg.value > 0, "must send CTC");
        require(token != address(0), "invalid token");

        Pool storage pool = pools[token];

        uint256 tokenAmount;
        if (pool.totalShares == 0) {
            // First provider sets ratio; pull whatever they approved
            tokenAmount = IERC20(token).allowance(msg.sender, address(this));
            require(tokenAmount > 0, "must approve tokens");
            sharesMinted = msg.value; // initial shares = CTC deposited
        } else {
            // Proportional deposit
            tokenAmount = (msg.value * pool.tokenReserve) / pool.ctcReserve;
            require(tokenAmount > 0, "token amount too small");
            sharesMinted = (msg.value * pool.totalShares) / pool.ctcReserve;
        }

        require(
            IERC20(token).transferFrom(msg.sender, address(this), tokenAmount),
            "token transfer failed"
        );

        pool.ctcReserve += msg.value;
        pool.tokenReserve += tokenAmount;
        pool.totalShares += sharesMinted;
        shares[token][msg.sender] += sharesMinted;

        emit LiquidityAdded(msg.sender, token, msg.value, tokenAmount, sharesMinted);
    }

    /**
     * @notice Remove liquidity by burning shares.
     */
    function removeLiquidity(address token, uint256 sharesToBurn) external {
        Pool storage pool = pools[token];
        require(sharesToBurn > 0, "zero shares");
        require(shares[token][msg.sender] >= sharesToBurn, "insufficient shares");
        require(pool.totalShares > 0, "no liquidity");

        uint256 ctcAmount = (sharesToBurn * pool.ctcReserve) / pool.totalShares;
        uint256 tokenAmount = (sharesToBurn * pool.tokenReserve) / pool.totalShares;

        shares[token][msg.sender] -= sharesToBurn;
        pool.totalShares -= sharesToBurn;
        pool.ctcReserve -= ctcAmount;
        pool.tokenReserve -= tokenAmount;

        payable(msg.sender).transfer(ctcAmount);
        require(
            IERC20(token).transfer(msg.sender, tokenAmount),
            "token transfer failed"
        );

        emit LiquidityRemoved(msg.sender, token, ctcAmount, tokenAmount, sharesToBurn);
    }

    /**
     * @notice Swap CTC for tokens. 0.3% fee applied to input.
     */
    function swapCTCForToken(address token, uint256 minAmountOut) external payable {
        require(msg.value > 0, "must send CTC");
        Pool storage pool = pools[token];
        require(pool.ctcReserve > 0 && pool.tokenReserve > 0, "no liquidity");

        uint256 amountInWithFee = msg.value * 997;
        uint256 numerator = amountInWithFee * pool.tokenReserve;
        uint256 denominator = (pool.ctcReserve * 1000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut >= minAmountOut, "slippage exceeded");
        require(amountOut <= pool.tokenReserve, "insufficient reserve");

        pool.ctcReserve += msg.value;
        pool.tokenReserve -= amountOut;

        require(
            IERC20(token).transfer(msg.sender, amountOut),
            "token transfer failed"
        );

        emit Swap(msg.sender, token, true, msg.value, amountOut);
    }

    /**
     * @notice Swap tokens for CTC. Token must be approved first. 0.3% fee applied.
     */
    function swapTokenForCTC(address token, uint256 amountIn, uint256 minAmountOut) external {
        require(amountIn > 0, "zero input");
        Pool storage pool = pools[token];
        require(pool.ctcReserve > 0 && pool.tokenReserve > 0, "no liquidity");

        require(
            IERC20(token).transferFrom(msg.sender, address(this), amountIn),
            "token transfer failed"
        );

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * pool.ctcReserve;
        uint256 denominator = (pool.tokenReserve * 1000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut >= minAmountOut, "slippage exceeded");
        require(amountOut <= pool.ctcReserve, "insufficient reserve");

        pool.tokenReserve += amountIn;
        pool.ctcReserve -= amountOut;

        payable(msg.sender).transfer(amountOut);

        emit Swap(msg.sender, token, false, amountIn, amountOut);
    }

    /**
     * @notice Get an estimated output amount for a swap (before fees applied).
     */
    function getQuote(
        address token,
        uint256 amountIn,
        bool ctcToToken
    ) external view returns (uint256 amountOut) {
        Pool storage pool = pools[token];
        require(pool.ctcReserve > 0 && pool.tokenReserve > 0, "no liquidity");

        uint256 amountInWithFee = amountIn * 997;
        if (ctcToToken) {
            uint256 numerator = amountInWithFee * pool.tokenReserve;
            uint256 denominator = (pool.ctcReserve * 1000) + amountInWithFee;
            amountOut = numerator / denominator;
        } else {
            uint256 numerator = amountInWithFee * pool.ctcReserve;
            uint256 denominator = (pool.tokenReserve * 1000) + amountInWithFee;
            amountOut = numerator / denominator;
        }
    }

    /**
     * @notice Return reserves for a given token pool.
     */
    function getReserves(address token) external view returns (uint256 ctcReserve, uint256 tokenReserve) {
        Pool storage pool = pools[token];
        ctcReserve = pool.ctcReserve;
        tokenReserve = pool.tokenReserve;
    }

    receive() external payable {}
}
