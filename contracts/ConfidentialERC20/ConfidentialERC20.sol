// SPDX-License-Identifier: BSD-3-Clause-Clear


pragma solidity ^0.8.24;

import { IConfidentialERC20 } from "./Interfaces/IConfidentialERC20.sol";
import { IERC20Metadata } from "./Utils/IERC20Metadata.sol";

import { IERC20Errors } from "./Utils/IERC6093.sol";
import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 6. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ConfidentialERC20 is Ownable, IConfidentialERC20, IERC20Metadata, IERC20Errors, GatewayCaller {
    mapping(address account => euint64) public _balances;

    // To safely handle burn requests we must ensure we lock up an amount of token that is in-flight so that the
    // we can guarantee there will be sufficient balance to be burnt at the point that _burnCallback runs.
    mapping(address account => uint64) public _lockedBalances;

    mapping(address account => mapping(address spender => euint64)) internal _allowances;

    uint64 public _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    struct BurnRq {
        address account;
        uint64 amount;
        bool exists;
    }

    mapping(uint256 => BurnRq) public burnRqs;
    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 6;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint64) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (euint64) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, euint64 value) public virtual returns (bool) {
        require(TFHE.isSenderAllowed(value));
        address owner = msg.sender;
        _transfer(owner, to, value, TFHE.asEbool(true));
        return true;
    }

    function transfer(address to, einput encryptedAmount, bytes calldata inputProof) public virtual returns (bool) {
        transfer(to, TFHE.asEuint64(encryptedAmount, inputProof));
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (euint64) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, euint64 value) public virtual returns (bool) {
        require(TFHE.isSenderAllowed(value));
        address owner = msg.sender;
        _approve(owner, spender, value);
        return true;
    }

    function approve(address spender, einput encryptedAmount, bytes calldata inputProof) public virtual returns (bool) {
        approve(spender, TFHE.asEuint64(encryptedAmount, inputProof));
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint64`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, euint64 value) public virtual returns (bool) {
        require(TFHE.isSenderAllowed(value));
        address spender = msg.sender;
        ebool isTransferable = _decreaseAllowance(from, spender, value);
        _transfer(from, to, value, isTransferable);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        einput encryptedAmount,
        bytes calldata inputProof
    ) public virtual returns (bool) {
        transferFrom(from, to, TFHE.asEuint64(encryptedAmount, inputProof));
        return true;
    }

    /**
     * @dev Checks the available balance of an account exceeds amount
     */
    function _hasSufficientBalance(address owner, euint64 amount) internal virtual returns (ebool) {
        return TFHE.le(TFHE.add(amount, _lockedBalances[owner]), _balances[owner]);
    }

    function _hasSufficientBalance(address owner, uint64 amount) internal virtual returns (ebool) {
        return _hasSufficientBalance(owner, TFHE.asEuint64(amount));
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, euint64 value, ebool isTransferable) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        // Enforce sufficient balance constraint universally
        euint64 transferValue = TFHE.select(
            TFHE.and(_hasSufficientBalance(from, value), isTransferable),
            value,
            TFHE.asEuint64(0)
        );
        euint64 newBalanceTo = TFHE.add(_balances[to], transferValue);
        _balances[to] = newBalanceTo;
        TFHE.allow(newBalanceTo, address(this));
        TFHE.allow(newBalanceTo, to);
        euint64 newBalanceFrom = TFHE.sub(_balances[from], transferValue);
        _balances[from] = newBalanceFrom;
        TFHE.allow(newBalanceFrom, address(this));
        TFHE.allow(newBalanceFrom, from);
        emit Transfer(from, to, transferValue);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint64 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _balances[account] = TFHE.add(_balances[account], value);
        TFHE.allow(_balances[account], address(this));
        TFHE.allow(_balances[account], account);
        _totalSupply += value;
    }

    event BurnRequested(uint256 requestId, address account, uint64 amount);

    event BurnRequestCancelled(uint256 requestID);

    error BurnRequestDoesNotExist(uint256 requestId);

    function _cancelBurn(uint256 requestId) internal virtual {
        BurnRq memory burnRequest = burnRqs[requestId];
        if (!burnRequest.exists) {
            revert BurnRequestDoesNotExist(requestId);
        }
        address account = burnRequest.account;
        uint64 amount = burnRequest.amount;
        // Unlock the burn amount unconditionally
        _lockedBalances[account] = _lockedBalances[account] - amount;
        delete burnRqs[requestId];
        emit BurnRequestCancelled(requestId);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _requestBurn(address account, uint64 amount) internal virtual {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        ebool enoughBalance = _hasSufficientBalance(account, amount);
        // Unconditionally lock the burn amount after calculating sufficient balance
        _lockedBalances[account] = _lockedBalances[account] + amount;
        TFHE.allow(enoughBalance, address(this));
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(enoughBalance);
        // Store burn request
        uint256 requestID = Gateway.requestDecryption(
            cts,
            this._burnCallback.selector,
            0,
            block.timestamp + 100,
            false
        );
        burnRqs[requestID] = BurnRq(account, amount, true);
        emit BurnRequested(requestID, account, amount);
    }

    event InsufficientBalanceToBurn(address account, uint64 burnAmount);

    function _burnCallback(uint256 requestID, bool hasEnoughBalance) public virtual onlyGateway {
        BurnRq memory burnRequest = burnRqs[requestID];
        if (!burnRequest.exists) {
            revert BurnRequestDoesNotExist(requestID);
        }
        address account = burnRequest.account;
        uint64 amount = burnRequest.amount;
        // Unlock the burn amount unconditionally
        _lockedBalances[account] = _lockedBalances[account] - amount;
        delete burnRqs[requestID];
        if (!hasEnoughBalance) {
            emit InsufficientBalanceToBurn(account, amount);
            return;
        }
        _totalSupply = _totalSupply - amount;
        _balances[account] = TFHE.sub(_balances[account], amount);
        TFHE.allow(_balances[account], address(this));
        TFHE.allow(_balances[account], account);
    }
    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, euint64 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, euint64 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, euint64 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
        TFHE.allow(value, address(this));
        TFHE.allow(value, owner);
        TFHE.allow(value, spender);
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Reduces `owner` s allowance for `spender` based on spent `value`.
     *
     *
     * Does not emit an {Approval} event.
     */
    function _decreaseAllowance(address owner, address spender, euint64 amount) internal virtual returns (ebool) {
        euint64 currentAllowance = _allowances[owner][spender];
        ebool isTransferable = TFHE.le(amount, currentAllowance);
        _approve(owner, spender, TFHE.select(isTransferable, TFHE.sub(currentAllowance, amount), currentAllowance));
        return isTransferable;
    }

    /**
     * @dev Increases `owner` s allowance for `spender` based on spent `value`.
     *
     *
     * Does not emit an {Approval} event.
     */
    function _increaseAllowance(address spender, euint64 addedValue) internal virtual returns (ebool) {
        require(TFHE.isSenderAllowed(addedValue));
        address owner = msg.sender;
        ebool isTransferable = TFHE.le(addedValue, _balances[owner]);
        euint64 newAllowance = TFHE.add(_allowances[owner][spender], addedValue);
        TFHE.allow(newAllowance, address(this));
        TFHE.allow(newAllowance, owner);
        _approve(owner, spender, newAllowance);
        return isTransferable;
    }

    function increaseAllowance(address spender, euint64 addedValue) public virtual returns (ebool) {
        return _increaseAllowance(spender, addedValue);
    }

    function increaseAllowance(
        address spender,
        einput encryptedAmount,
        bytes calldata inputProof
    ) public virtual returns (ebool) {
        return increaseAllowance(spender, TFHE.asEuint64(encryptedAmount, inputProof));
    }

    function decreaseAllowance(address spender, euint64 subtractedValue) public virtual returns (ebool) {
        require(TFHE.isSenderAllowed(subtractedValue));
        return _decreaseAllowance(msg.sender, spender, subtractedValue);
    }

    function decreaseAllowance(
        address spender,
        einput encryptedAmount,
        bytes calldata inputProof
    ) public virtual returns (ebool) {
        return decreaseAllowance(spender, TFHE.asEuint64(encryptedAmount, inputProof));
    }
}
