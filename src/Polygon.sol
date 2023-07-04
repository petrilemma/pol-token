// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20, ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IMinterImplementation} from "./IMinterImplementation.sol";

/// @custom:security-contact security@polygon.technology
contract Polygon is Ownable2Step, ERC20Permit {
    address public immutable hub;
    address public immutable treasury;
    uint256 public immutable inflationModificationTimestamp;
    uint256 private immutable _mintPerSecond = 3170979198376458650;
    uint256 public lastMint;
    uint256 public lastHubMint;
    uint256 public lastTreasuryMint;
    uint256 public hubMintPerSecond;
    uint256 public treasuryMintPerSecond;
    uint256 private _INFLATION_LOCK = 1;
    IMinterImplementation public minterImpl;

    error Invalid(string msg);

    constructor(address migration_, address hub_, address treasury_, IMinterImplementation minterImpl_, address owner_)
        ERC20("Polygon", "POL")
        ERC20Permit("Polygon")
    {
        hub = hub_;
        treasury = treasury_;
        minterImpl = minterImpl_;
        lastMint = block.timestamp;
        inflationModificationTimestamp = block.timestamp + 315360000;
        _mint(migration_, 10_000_000_000e18);
        _transferOwnership(owner_);
    }

    function mint() public {
        if (_INFLATION_LOCK == 0) {
            revert Invalid("inflation rate is unlocked");
        }
        uint256 amount = (block.timestamp - lastMint) * _mintPerSecond;
        lastMint = block.timestamp;
        _mint(hub, amount);
        _mint(treasury, amount);
    }

    function mintAfterUnlock() external {
        if (_INFLATION_LOCK == 1) {
            revert Invalid("inflation rate is locked");
        }
        uint256 newHubMintPerSecond = minterImpl.getHubMintPerSecond();
        uint256 newTreasuryMintPerSecond = minterImpl.getTreasuryMintPerSecond();
        if (newHubMintPerSecond > _mintPerSecond) {
            newHubMintPerSecond = _mintPerSecond;
        }
        if (newTreasuryMintPerSecond > _mintPerSecond) {
            newTreasuryMintPerSecond = _mintPerSecond;
        }
        uint256 _lastMint = lastMint;
        _mint(hub, (block.timestamp - _lastMint) * newHubMintPerSecond);
        _mint(treasury, (block.timestamp - _lastMint) * newTreasuryMintPerSecond);
        lastMint = block.timestamp;
    }

    function unlockInflation() external onlyOwner {
        if (block.timestamp < inflationModificationTimestamp) {
            revert Invalid("too early to unlock inflation");
        }
        mint();
        delete _INFLATION_LOCK;
    }
}
