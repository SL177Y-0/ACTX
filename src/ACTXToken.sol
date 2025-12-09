// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IACTXToken} from "./interfaces/IACTXToken.sol";

/**
 * @title ACTXToken
 * @author BlessUP Team
 * @notice ACT.X - The BlessUP Rewards Token for positive action micro-rewards
 * @dev UUPS-upgradeable ERC-20 with transaction tax recycling mechanism
 */
contract ACTXToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IACTXToken
{
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10 ** 18;
    uint256 public constant MAX_TAX_RATE_BPS = 1000;
    uint256 private constant _BPS_DENOMINATOR = 10_000;

    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @custom:storage-location erc7201:actx.token.storage
    struct ACTXStorage {
        uint256 taxRateBps;
        address reservoir;
        mapping(address => bool) taxExempt;
        address treasury;
    }

    bytes32 private constant ACTX_STORAGE_SLOT =
        0x8a35acfbc15ff81a39ae7d344fd709f28e8600b4aa8c65c6b64bfe7fe36bd100;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _treasury,
        address _reservoir,
        address _admin,
        uint256 _initialTaxRateBps
    ) external initializer {
        if (_treasury == address(0)) revert ZeroAddressNotAllowed();
        if (_reservoir == address(0)) revert ZeroAddressNotAllowed();
        if (_admin == address(0)) revert ZeroAddressNotAllowed();
        if (_initialTaxRateBps > MAX_TAX_RATE_BPS) {
            revert TaxRateExceedsMaximum(_initialTaxRateBps, MAX_TAX_RATE_BPS);
        }

        __ERC20_init("ACT.X Token", "ACTX");
        __ERC20Permit_init("ACT.X Token");
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(TAX_MANAGER_ROLE, _admin);

        ACTXStorage storage $ = _getACTXStorage();
        $.taxRateBps = _initialTaxRateBps;
        $.reservoir = _reservoir;
        $.treasury = _treasury;

        $.taxExempt[_treasury] = true;
        $.taxExempt[_reservoir] = true;
        $.taxExempt[address(this)] = true;

        _mint(_treasury, TOTAL_SUPPLY);
    }

    function distributeReward(
        address to,
        uint256 amount,
        bytes32 activityId
    ) external override onlyRole(REWARD_MANAGER_ROLE) nonReentrant whenNotPaused {
        if (to == address(0)) revert ZeroAddressNotAllowed();
        if (amount == 0) revert ZeroAmountNotAllowed();

        uint256 poolBalance = balanceOf(address(this));
        if (poolBalance < amount) {
            revert InsufficientRewardPool(amount, poolBalance);
        }

        _transfer(address(this), to, amount);
        emit RewardDistributed(to, amount, activityId, block.timestamp);
    }

    function batchDistributeRewards(
        address[] calldata recipients,
        uint256[] calldata amounts,
        bytes32[] calldata activityIds
    ) external override onlyRole(REWARD_MANAGER_ROLE) nonReentrant whenNotPaused {
        uint256 length = recipients.length;
        require(length == amounts.length && length == activityIds.length, "Array length mismatch");
        require(length > 0, "Empty arrays");

        uint256 poolBalance = balanceOf(address(this));
        uint256 totalAmount;

        for (uint256 i; i < length; ) {
            if (recipients[i] == address(0)) revert ZeroAddressNotAllowed();
            if (amounts[i] == 0) revert ZeroAmountNotAllowed();
            totalAmount += amounts[i];
            unchecked { ++i; }
        }

        if (poolBalance < totalAmount) {
            revert InsufficientRewardPool(totalAmount, poolBalance);
        }

        for (uint256 i; i < length; ) {
            _transfer(address(this), recipients[i], amounts[i]);
            emit RewardDistributed(recipients[i], amounts[i], activityIds[i], block.timestamp);
            unchecked { ++i; }
        }
    }

    function setTaxRate(uint256 newTaxRateBps) external override onlyRole(TAX_MANAGER_ROLE) {
        if (newTaxRateBps > MAX_TAX_RATE_BPS) {
            revert TaxRateExceedsMaximum(newTaxRateBps, MAX_TAX_RATE_BPS);
        }

        ACTXStorage storage $ = _getACTXStorage();
        uint256 oldRate = $.taxRateBps;
        $.taxRateBps = newTaxRateBps;

        emit TaxRateUpdated(oldRate, newTaxRateBps, msg.sender);
    }

    function setReservoir(address newReservoir) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newReservoir == address(0)) revert ZeroAddressNotAllowed();

        ACTXStorage storage $ = _getACTXStorage();
        address oldReservoir = $.reservoir;

        $.taxExempt[oldReservoir] = false;
        $.taxExempt[newReservoir] = true;
        $.reservoir = newReservoir;

        emit ReservoirUpdated(oldReservoir, newReservoir, msg.sender);
    }

    function setTaxExempt(address account, bool exempt) external override onlyRole(TAX_MANAGER_ROLE) {
        if (account == address(0)) revert ZeroAddressNotAllowed();

        ACTXStorage storage $ = _getACTXStorage();
        $.taxExempt[account] = exempt;

        emit TaxExemptionUpdated(account, exempt, msg.sender);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function taxRateBps() external view override returns (uint256) {
        return _getACTXStorage().taxRateBps;
    }

    function reservoir() external view override returns (address) {
        return _getACTXStorage().reservoir;
    }

    function isTaxExempt(address account) external view override returns (bool) {
        return _getACTXStorage().taxExempt[account];
    }

    function treasury() external view returns (address) {
        return _getACTXStorage().treasury;
    }

    function rewardPoolBalance() external view override returns (uint256) {
        return balanceOf(address(this));
    }

    function circulatingSupply() external view override returns (uint256) {
        return totalSupply() - balanceOf(address(this));
    }

    function calculateTax(uint256 amount) public view override returns (uint256) {
        return (amount * _getACTXStorage().taxRateBps) / _BPS_DENOMINATOR;
    }

    function _update(address from, address to, uint256 value) internal virtual override whenNotPaused {
        ACTXStorage storage $ = _getACTXStorage();

        bool shouldTax = from != address(0) && to != address(0) &&
                         !$.taxExempt[from] && !$.taxExempt[to] && $.taxRateBps > 0;

        if (shouldTax) {
            uint256 taxAmount = calculateTax(value);
            uint256 netAmount = value - taxAmount;

            if (taxAmount > 0) {
                super._update(from, $.reservoir, taxAmount);
                emit TaxCollected(from, taxAmount, to);
            }
            super._update(from, to, netAmount);
        } else {
            super._update(from, to, value);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function _getACTXStorage() private pure returns (ACTXStorage storage $) {
        assembly {
            $.slot := ACTX_STORAGE_SLOT
        }
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
