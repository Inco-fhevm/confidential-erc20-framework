// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { IConfidentialERC20 } from "./IConfidentialERC20.sol";

/**
 * @dev Interface of the Confidential ERC-20 wrapper.
 */

    interface IConfidentialERC20Wrapper is IConfidentialERC20 {
        /**
         * @dev Returns the base ERC-20 token address.
         */
        function baseERC20() external view returns (address);

        /**
         * @dev Returns the decimals of the base ERC-20 token.
         */
        function decimals() external view returns (uint8);

        /**
         * @dev Wraps a `amount` of base ERC-20 tokens into the wrapper.
         */
        function wrap(uint64 amount) external;

        /**
         * @dev Unwraps a `amount` of wrapped tokens into the base ERC-20 token.
         */
        function unwrap(uint256 amount) external;

        function setUnwrapStatus(address account, bool status) external;

        

        event Wrap(address indexed account, uint64 amount);
        event Unwrap(address indexed account, uint64 amount);

    }
