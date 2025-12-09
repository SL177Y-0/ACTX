// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Airdrop
 * @notice ACT.X Token Airdrop with Merkle Proof Verification
 */
contract Airdrop is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public merkleRoot;
    uint256 public claimDeadline;
    mapping(address => bool) public hasClaimed;
    uint256 public totalClaimed;
    uint256 public totalAllocated;
    bool public isActive;

    event Claimed(address indexed account, uint256 amount);
    event MerkleRootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);
    event AirdropStatusChanged(bool active);
    event TokensRecovered(uint256 amount, address indexed to);

    error AirdropNotActive();
    error ClaimDeadlinePassed();
    error ClaimDeadlineNotPassed();
    error AlreadyClaimed();
    error InvalidProof();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidMerkleRoot();
    error InsufficientBalance();

    constructor(address _token, address _owner) Ownable(_owner) {
        if (_token == address(0)) revert ZeroAddress();
        token = IERC20(_token);
    }

    function initializeAirdrop(bytes32 _merkleRoot, uint256 _claimDeadline, uint256 _totalAllocated) external onlyOwner {
        if (_merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (_claimDeadline <= block.timestamp) revert ClaimDeadlinePassed();
        if (_totalAllocated == 0) revert ZeroAmount();

        bytes32 oldRoot = merkleRoot;
        merkleRoot = _merkleRoot;
        claimDeadline = _claimDeadline;
        totalAllocated = _totalAllocated;
        totalClaimed = 0;
        isActive = true;

        emit MerkleRootUpdated(oldRoot, _merkleRoot);
        emit AirdropStatusChanged(true);
    }

    function updateMerkleRoot(bytes32 _newRoot) external onlyOwner {
        if (_newRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (block.timestamp >= claimDeadline) revert ClaimDeadlinePassed();

        bytes32 oldRoot = merkleRoot;
        merkleRoot = _newRoot;
        emit MerkleRootUpdated(oldRoot, _newRoot);
    }

    function setActive(bool _active) external onlyOwner {
        isActive = _active;
        emit AirdropStatusChanged(_active);
    }

    function extendDeadline(uint256 _newDeadline) external onlyOwner {
        require(_newDeadline > claimDeadline, "New deadline must be later");
        claimDeadline = _newDeadline;
    }

    function recoverUnclaimedTokens(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (block.timestamp < claimDeadline) revert ClaimDeadlineNotPassed();

        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert ZeroAmount();

        token.safeTransfer(to, balance);
        isActive = false;
        emit TokensRecovered(balance, to);
    }

    function claim(uint256 amount, bytes32[] calldata merkleProof) external nonReentrant {
        _claim(msg.sender, amount, merkleProof);
    }

    function claimFor(address account, uint256 amount, bytes32[] calldata merkleProof) external nonReentrant {
        _claim(account, amount, merkleProof);
    }

    function _claim(address account, uint256 amount, bytes32[] calldata merkleProof) internal {
        if (!isActive) revert AirdropNotActive();
        if (block.timestamp >= claimDeadline) revert ClaimDeadlinePassed();
        if (hasClaimed[account]) revert AlreadyClaimed();
        if (amount == 0) revert ZeroAmount();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) revert InvalidProof();
        if (token.balanceOf(address(this)) < amount) revert InsufficientBalance();

        hasClaimed[account] = true;
        totalClaimed += amount;
        token.safeTransfer(account, amount);
        emit Claimed(account, amount);
    }

    function canClaim(address account, uint256 amount, bytes32[] calldata merkleProof) external view returns (bool, string memory) {
        if (!isActive) return (false, "Airdrop not active");
        if (block.timestamp >= claimDeadline) return (false, "Deadline passed");
        if (hasClaimed[account]) return (false, "Already claimed");
        if (amount == 0) return (false, "Zero amount");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) return (false, "Invalid proof");
        if (token.balanceOf(address(this)) < amount) return (false, "Insufficient balance");

        return (true, "");
    }

    function remainingTokens() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function timeUntilDeadline() external view returns (uint256) {
        if (block.timestamp >= claimDeadline) return 0;
        return claimDeadline - block.timestamp;
    }

    function verifyProof(address account, uint256 amount, bytes32[] calldata merkleProof) external view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }

    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        if (tokenAddress == address(token) && isActive) revert("Cannot recover airdrop token while active");
        IERC20(tokenAddress).safeTransfer(owner(), amount);
    }
}
