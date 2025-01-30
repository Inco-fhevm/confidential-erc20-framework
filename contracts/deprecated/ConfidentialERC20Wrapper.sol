// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
import { ConfidentialToken } from "./ConfidentialERC20/ConfidentialToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
interface IERC20extended is IERC20 {
    function decimals() external view returns (uint8);
}

contract ConfidentialERC20Wrapper is ConfidentialToken {
    using SafeERC20 for IERC20;
    IERC20 public baseERC20;
    mapping(address => bool) public unwrapDisabled;
    uint8 private _decimals;
    event Wrap(address indexed account, uint64 amount);
    event Unwrap(address indexed account, uint64 amount);
    event Burn(address indexed account, uint64 amount);

    error UnwrapNotAllowed(address account);

    constructor(address _baseERC20) ConfidentialToken("Wrapped cERC20", "wcERC20") {
        uint8 baseERCdecimals = IERC20extended(_baseERC20).decimals();
        require(baseERCdecimals <= 6, "Base ERC20 token must have 6 or less decimals");
        baseERC20 = IERC20(_baseERC20);
        _decimals = baseERCdecimals;
        // set the wrapper decimals to be the same as the base token
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function wrap(uint64 amount) external {
        uint256 _amount = uint256(amount);
        uint256 allowance = baseERC20.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Not enough allowance");
        baseERC20.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, uint64(amount));
        emit Wrap(msg.sender, amount);
    }

    function unwrap(uint256 amount) external {
        if (unwrapDisabled[msg.sender]) {
            revert UnwrapNotAllowed(msg.sender);
        }

        _requestBurn(msg.sender, uint64(amount));
    }

    function _burnCallback(uint256 requestID, bool decryptedInput) public virtual override onlyGateway {
        BurnRq memory burnRequest = burnRqs[requestID];
        address account = burnRequest.account;
        uint64 amount = burnRequest.amount;

        if (!decryptedInput) {
            revert("Decryption failed");
        }

        // Call base ERC20 transfer and emit Unwrap event
        baseERC20.safeTransfer(account, amount);
        emit Unwrap(account, amount);

        // Continue with the burn logic
        _totalSupply -= amount;
        _balances[account] = TFHE.sub(_balances[account], amount);
        TFHE.allow(_balances[account], address(this));
        TFHE.allow(_balances[account], account);
        delete burnRqs[requestID];
    }
}
