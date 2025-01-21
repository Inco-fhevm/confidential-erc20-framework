// SPDX-License-Identifier: BSD-3-Clause-Clear


pragma solidity ^0.8.24;

import { IConfidentialERC20 } from "../Interfaces/IConfidentialERC20.sol";
import "fhevm/lib/TFHE.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IConfidentialERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}
