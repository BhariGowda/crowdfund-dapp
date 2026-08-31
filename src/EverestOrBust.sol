// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";

/// @title EverestOrBust
/// @author Bhari Gowda
/// @notice Stablecoin fundraise for the Everest summit attempt, 2027, on Avalanche C-Chain.
///         $69,000 goal. 69-day campaign (Dec 10 2026 - Feb 17 2027).
///         Accepts USDC and USDT only. No price oracle needed.
///         Each address may contribute at most $6.9 total across both tokens.
///         If the goal is not reached, contributors may refund in full.
/// @dev    Both USDC and USDT are 6 decimals on Avalanche C-Chain. All internal
///         accounting is normalized to 18 decimals for consistency with the
///         $6.9/$69,000 constants, scaled by 1e12.
contract EverestOrBust {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum contribution per address, normalized to 18 decimals ($6.9)
    uint256 public constant CAP_PER_ADDRESS = 6.9e18;
    /// @notice Funding goal, normalized to 18 decimals ($69,000)
    uint256 public constant GOAL = 69_000e18;
    /// @notice Campaign duration in days
    uint256 public constant DURATION_DAYS = 69;
    /// @notice Scale factor for 6-decimal tokens (USDC, USDT)
    uint256 private constant SCALE_6 = 1e12;

    /*//////////////////////////////////////////////////////////////
                          REENTRANCY GUARD
    //////////////////////////////////////////////////////////////*/

    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Reentrancy();
    error NotCreator();
    error CampaignNotStarted();
    error InvalidStartTime();
    error CampaignEnded();
    error CampaignNotEnded();
    error GoalNotReached();
    error GoalReached();
    error AlreadyWithdrawn();
    error UnsupportedToken();
    error ZeroAmount();
    error CapExceeded();
    error NothingToRefund();
    error TokenTransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Contributed(address indexed contributor, address indexed token, uint256 amount, uint256 normalized);
    event Withdrawn(address indexed creator, uint256 usdc, uint256 usdt);
    event Refunded(address indexed contributor, uint256 usdc, uint256 usdt);
    event TransferStuck(address indexed to, address indexed token, uint256 amount);
    event StuckClaimed(address indexed to, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable creator;
    uint256 public immutable start;
    uint256 public immutable deadline;

    address public immutable USDC;
    address public immutable USDT;

    /// @notice Total raised across both tokens, normalized to 18 decimals
    uint256 public totalRaisedNormalized;

    /// @notice Per-contributor total contributed, normalized
    mapping(address => uint256) public contributedNormalized;

    /// @notice Per-contributor raw token contributions (native decimals)
    mapping(address => uint256) public contributedUSDC;
    mapping(address => uint256) public contributedUSDT;

    bool public withdrawn;

    /// @notice Total number of unique addresses that have ever contributed.
    /// @dev Intentionally NOT decremented on refund — this tracks historical
    ///      participation ("X people believed in this"), not current pool membership.
    uint256 public contributorCount;

    /// @notice Amount of a given token stuck for a given address due to a failed
    ///         transfer (e.g. USDC/USDT compliance blacklist). Reclaimable via claimStuck().
    mapping(address => mapping(address => uint256)) public stuckBalance;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _creator Address entitled to withdraw if goal is met
    /// @param _usdc    USDC token address (Avalanche C-Chain native USDC)
    /// @param _usdt    USDT token address (Avalanche C-Chain)
    /// @param _start   Campaign start timestamp (Dec 10 2026 = 1765324800)
    constructor(address _creator, address _usdc, address _usdt, uint256 _start) {
        if (_creator == address(0)) revert NotCreator();
        if (_usdc == address(0) || _usdt == address(0)) revert UnsupportedToken();
        if (_start < block.timestamp) revert InvalidStartTime();
        creator = _creator;
        USDC = _usdc;
        USDT = _usdt;
        start = _start;
        deadline = _start + (DURATION_DAYS * 1 days);
    }

    /*//////////////////////////////////////////////////////////////
                            CONTRIBUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Contribute `amount` of `token` to the campaign.
    /// @dev Caller must approve this contract first.
    ///      Excess above the $6.9 per-address cap is automatically rejected —
    ///      only the capped amount is pulled.
    /// @param token  USDC or USDT address
    /// @param amount Amount in the token's native decimals
    function contribute(address token, uint256 amount) external nonReentrant {
        if (block.timestamp < start) revert CampaignNotStarted();
        if (block.timestamp > deadline) revert CampaignEnded();
        if (amount == 0) revert ZeroAmount();
        if (contributedNormalized[msg.sender] >= CAP_PER_ADDRESS) revert CapExceeded();
        if (totalRaisedNormalized >= GOAL) revert GoalReached();

        uint256 normalized = _normalize(token, amount);

        // Cap to whichever is smaller: the caller's remaining per-address allowance,
        // or the campaign's remaining goal. Both must be respected simultaneously so
        // totalRaisedNormalized can never exceed GOAL, matching the documented
        // "contributions close automatically at $69,000" behavior exactly.
        uint256 remainingAllowance = CAP_PER_ADDRESS - contributedNormalized[msg.sender];
        uint256 remainingGoal = GOAL - totalRaisedNormalized;
        uint256 capLimit = remainingAllowance < remainingGoal ? remainingAllowance : remainingGoal;

        if (normalized > capLimit) {
            normalized = capLimit;
            amount = _denormalize(normalized);
        }

        // Pull tokens and require the exact requested amount to arrive. USDC and USDT
        // are the only two tokens this campaign accepts, and neither charges transfer
        // fees — rather than silently reconciling a mismatch (which can desync token
        // accounting from normalized accounting), a divergence here means something
        // is genuinely wrong with the token and the transaction reverts loudly.
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        _pullToken(token, msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balanceBefore;
        if (received != amount) revert TokenTransferFailed();

        if (contributedNormalized[msg.sender] == 0) contributorCount++;
        contributedNormalized[msg.sender] += normalized;
        totalRaisedNormalized += normalized;

        if (token == USDC) contributedUSDC[msg.sender] += amount;
        else contributedUSDT[msg.sender] += amount;

        emit Contributed(msg.sender, token, amount, normalized);
    }

    /*//////////////////////////////////////////////////////////////
                              WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraw all funds to the creator after a successful campaign.
    function withdraw() external nonReentrant {
        if (msg.sender != creator) revert NotCreator();
        if (block.timestamp <= deadline) revert CampaignNotEnded();
        if (totalRaisedNormalized < GOAL) revert GoalNotReached();
        if (withdrawn) revert AlreadyWithdrawn();
        withdrawn = true;

        uint256 usdcBal = IERC20(USDC).balanceOf(address(this));
        uint256 usdtBal = IERC20(USDT).balanceOf(address(this));

        // Each token transfer is isolated so a single blacklisted/frozen token
        // (e.g. USDC/USDT compliance freeze) cannot trap funds in the other.
        if (usdcBal > 0) _trySendToken(USDC, creator, usdcBal);
        if (usdtBal > 0) _trySendToken(USDT, creator, usdtBal);

        emit Withdrawn(creator, usdcBal, usdtBal);
    }

    /*//////////////////////////////////////////////////////////////
                               REFUND
    //////////////////////////////////////////////////////////////*/

    /// @notice Reclaim full contribution if the goal was not met by deadline.
    function refund() external nonReentrant {
        if (block.timestamp <= deadline) revert CampaignNotEnded();
        if (totalRaisedNormalized >= GOAL) revert GoalReached();

        uint256 normalizedAmt = contributedNormalized[msg.sender];
        uint256 usdcAmt = contributedUSDC[msg.sender];
        uint256 usdtAmt = contributedUSDT[msg.sender];
        if (usdcAmt == 0 && usdtAmt == 0) revert NothingToRefund();

        contributedUSDC[msg.sender] = 0;
        contributedUSDT[msg.sender] = 0;
        contributedNormalized[msg.sender] = 0;
        totalRaisedNormalized -= normalizedAmt;

        // Each token transfer is isolated so a single blacklisted/frozen token
        // cannot trap the contributor's refund in the other.
        if (usdcAmt > 0) _trySendToken(USDC, msg.sender, usdcAmt);
        if (usdtAmt > 0) _trySendToken(USDT, msg.sender, usdtAmt);
        emit Refunded(msg.sender, usdcAmt, usdtAmt);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice True if the campaign is currently accepting contributions
    function isActive() external view returns (bool) {
        return block.timestamp >= start && block.timestamp <= deadline;
    }

    /// @notice Normalized USD amount still needed to reach the goal
    function remaining() external view returns (uint256) {
        if (totalRaisedNormalized >= GOAL) return 0;
        return GOAL - totalRaisedNormalized;
    }

    /// @notice Remaining contribution allowance for `contributor` in normalized USD
    function remainingCap(address contributor) external view returns (uint256) {
        uint256 contrib = contributedNormalized[contributor];
        if (contrib >= CAP_PER_ADDRESS) return 0;
        return CAP_PER_ADDRESS - contrib;
    }

    /// @notice Current pool balance per token, for frontend display.
    /// @return usdcBal Current USDC balance held by this contract
    /// @return usdtBal Current USDT balance held by this contract
    function getPoolBreakdown() external view returns (uint256 usdcBal, uint256 usdtBal) {
        usdcBal = IERC20(USDC).balanceOf(address(this));
        usdtBal = IERC20(USDT).balanceOf(address(this));
    }

    /// @notice Campaign lifecycle status, so frontends don't need to replicate this logic.
    /// @return status 0 = not started, 1 = active, 2 = ended, goal reached; 3 = ended, goal not reached
    function getCampaignStatus() external view returns (uint8 status) {
        if (block.timestamp < start) return 0;
        if (block.timestamp <= deadline) return 1;
        if (totalRaisedNormalized >= GOAL) return 2;
        return 3;
    }

    /// @notice Reclaim a token transfer that previously failed (e.g. blacklisted by USDC/USDT).
    /// @param to    The address whose stuck balance is being claimed
    /// @param token USDC or USDT
    function claimStuck(address to, address token) external nonReentrant {
        uint256 amount = stuckBalance[to][token];
        if (amount == 0) revert NothingToRefund();
        stuckBalance[to][token] = 0;
        _sendToken(token, to, amount);
        emit StuckClaimed(to, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Both USDC and USDT are 6 decimals on Avalanche — always scale up by 1e12.
    function _normalize(address token, uint256 amount) internal view returns (uint256) {
        if (token != USDC && token != USDT) revert UnsupportedToken();
        return amount * SCALE_6;
    }

    /// @dev Both tokens share 6 decimals, so denormalization doesn't need to branch by token.
    function _denormalize(uint256 normalized) internal pure returns (uint256) {
        return normalized / SCALE_6;
    }

    function _pullToken(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (ret.length != 0 && !abi.decode(ret, (bool)))) revert TokenTransferFailed();
    }

    function _sendToken(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (ret.length != 0 && !abi.decode(ret, (bool)))) revert TokenTransferFailed();
    }

    /// @dev Attempts a token transfer without reverting on failure. If the transfer
    ///      fails (e.g. `to` is blacklisted by USDC/USDT compliance controls), the
    ///      amount is recorded in `stuckBalance` instead of being lost, so it can be
    ///      reclaimed later via `claimStuck()` once the underlying issue is resolved.
    function _trySendToken(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        bool success = ok && (ret.length == 0 || abi.decode(ret, (bool)));
        if (!success) {
            stuckBalance[to][token] += amount;
            emit TransferStuck(to, token, amount);
        }
    }
}
