// SPDX-License-Identifier: MIT
// Inco

// todo choose a license
// todo company header

pragma solidity ^0.8.24;

import { IERC20Metadata } from "./Utils/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Errors } from "./Utils/IERC6093.sol";
import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

interface IConfidentialERC20 {}

abstract contract ConfidentialERC20 {}
