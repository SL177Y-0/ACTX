// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IACTXToken
 * @notice Interface for the ACT.X Token
 */
interface IACTXToken {
    event RewardDistributed(address indexed recipient, uint256 amount, bytes32 indexed activityId, uint256 timestamp);
    event TaxCollected(address indexed from, uint256 amount, address indexed recipient);
    event TaxRateUpdated(uint256 oldRate, uint256 newRate, address indexed changedBy);
    event ReservoirUpdated(address indexed oldReservoir, address indexed newReservoir, address indexed changedBy);
    event TaxExemptionUpdated(address indexed account, bool isExempt, address indexed changedBy);

    error TaxRateExceedsMaximum(uint256 requested, uint256 maximum);
    error ZeroAddressNotAllowed();
    error InsufficientRewardPool(uint256 requested, uint256 available);
    error UnauthorizedCaller(address caller, bytes32 requiredRole);
    error ZeroAmountNotAllowed();

    function distributeReward(address to, uint256 amount, bytes32 activityId) external;
    function batchDistributeRewards(address[] calldata recipients, uint256[] calldata amounts, bytes32[] calldata activityIds) external;
    function setTaxRate(uint256 newTaxRateBps) external;
    function setReservoir(address newReservoir) external;
    function setTaxExempt(address account, bool exempt) external;
    function taxRateBps() external view returns (uint256);
    function reservoir() external view returns (address);
    function isTaxExempt(address account) external view returns (bool);
    function rewardPoolBalance() external view returns (uint256);
    function circulatingSupply() external view returns (uint256);
    function calculateTax(uint256 amount) external view returns (uint256);
    function TOTAL_SUPPLY() external view returns (uint256);
    function MAX_TAX_RATE_BPS() external view returns (uint256);
}
