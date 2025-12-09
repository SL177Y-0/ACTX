// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Vesting
 * @notice ACT.X Team & Advisor Token Vesting (4-year total, 1-year cliff)
 */
contract Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 released;
        uint64 startTime;
        uint64 cliffDuration;
        uint64 vestingDuration;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule) public vestingSchedules;
    uint256 public totalVestingAmount;

    uint64 public constant DEFAULT_CLIFF = 365 days;
    uint64 public constant DEFAULT_VESTING = 4 * 365 days;

    event VestingScheduleCreated(address indexed beneficiary, uint256 amount, uint64 startTime, uint64 cliffDuration, uint64 vestingDuration);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 amountRevoked);

    error ZeroAddress();
    error ZeroAmount();
    error ScheduleAlreadyExists();
    error ScheduleDoesNotExist();
    error ScheduleNotRevocable();
    error ScheduleAlreadyRevoked();
    error NoTokensToClaim();
    error InsufficientContractBalance();
    error InvalidDuration();

    constructor(address _token, address _owner) Ownable(_owner) {
        if (_token == address(0)) revert ZeroAddress();
        token = IERC20(_token);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint64 startTime,
        uint64 cliffDuration,
        uint64 vestingDuration,
        bool revocable
    ) external onlyOwner {
        if (beneficiary == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (vestingSchedules[beneficiary].totalAmount > 0) revert ScheduleAlreadyExists();

        if (startTime == 0) startTime = uint64(block.timestamp);
        if (cliffDuration == 0) cliffDuration = DEFAULT_CLIFF;
        if (vestingDuration == 0) vestingDuration = DEFAULT_VESTING;
        if (cliffDuration > vestingDuration) revert InvalidDuration();

        uint256 availableBalance = token.balanceOf(address(this)) - totalVestingAmount;
        if (availableBalance < amount) revert InsufficientContractBalance();

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            released: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });

        totalVestingAmount += amount;
        emit VestingScheduleCreated(beneficiary, amount, startTime, cliffDuration, vestingDuration);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (schedule.totalAmount == 0) revert ScheduleDoesNotExist();
        if (!schedule.revocable) revert ScheduleNotRevocable();
        if (schedule.revoked) revert ScheduleAlreadyRevoked();

        uint256 vestedAmount = _computeVestedAmount(schedule);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        schedule.totalAmount = vestedAmount;
        totalVestingAmount -= unvestedAmount;

        if (unvestedAmount > 0) {
            token.safeTransfer(owner(), unvestedAmount);
        }

        emit VestingRevoked(beneficiary, unvestedAmount);
    }

    function release() external nonReentrant {
        _release(msg.sender);
    }

    function releaseFor(address beneficiary) external nonReentrant {
        _release(beneficiary);
    }

    function _release(address beneficiary) internal {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0) revert ScheduleDoesNotExist();

        uint256 vestedAmount = _computeVestedAmount(schedule);
        uint256 releasableAmount = vestedAmount - schedule.released;
        if (releasableAmount == 0) revert NoTokensToClaim();

        schedule.released += releasableAmount;
        totalVestingAmount -= releasableAmount;

        token.safeTransfer(beneficiary, releasableAmount);
        emit TokensReleased(beneficiary, releasableAmount);
    }

    function releasableAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0) return 0;
        return _computeVestedAmount(schedule) - schedule.released;
    }

    function vestedAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0) return 0;
        return _computeVestedAmount(schedule);
    }

    function unvestedAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0) return 0;
        return schedule.totalAmount - _computeVestedAmount(schedule);
    }

    function getVestingSchedule(address beneficiary) external view returns (VestingSchedule memory) {
        return vestingSchedules[beneficiary];
    }

    function _computeVestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        if (schedule.revoked) return schedule.totalAmount;

        uint256 currentTime = block.timestamp;
        uint256 start = schedule.startTime;
        uint256 cliff = start + schedule.cliffDuration;
        uint256 end = start + schedule.vestingDuration;

        if (currentTime < cliff) return 0;
        if (currentTime >= end) return schedule.totalAmount;

        uint256 vestingPeriod = end - cliff;
        uint256 elapsed = currentTime - cliff;
        return (schedule.totalAmount * elapsed) / vestingPeriod;
    }

    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        if (tokenAddress == address(token)) {
            uint256 excess = token.balanceOf(address(this)) - totalVestingAmount;
            require(amount <= excess, "Cannot recover committed tokens");
        }
        IERC20(tokenAddress).safeTransfer(owner(), amount);
    }
}
