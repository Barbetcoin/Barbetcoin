/*

#####################################
Token generated with ❤️ on 20lab.app
#####################################

*/


// SPDX-License-Identifier: No License
pragma solidity 0.8.25;

import {IERC20, ERC20} from "./ERC20.sol";
import {ERC20Burnable} from "./ERC20Burnable.sol";
import {Ownable, Ownable2Step} from "./Ownable2Step.sol";
import {Mintable} from "./Mintable.sol";
import {Pausable} from "./Pausable.sol";
import {SafeERC20Remastered} from "./SafeERC20Remastered.sol";

import {ERC20Permit} from "./ERC20Permit.sol";
import {Initializable} from "./Initializable.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapV2Router02.sol";

contract Barbet is ERC20, ERC20Burnable, Ownable2Step, Mintable, Pausable, ERC20Permit, Initializable {
    
    using SafeERC20Remastered for IERC20;
 
    mapping (address => bool) public blacklisted;

    IUniswapV2Router02 public routerV2;
    address public pairV2;
    mapping (address => bool) public AMMs;

    mapping (address => bool) public isExcludedFromLimits;

    mapping (address => uint256) public lastTrade;
    uint256 public tradeCooldownTime;

    bool public tradingEnabled;
    mapping (address => bool) public isExcludedFromTradingRestriction;
 
    error InvalidToken(address tokenAddress);

    error TransactionBlacklisted(address from, address to);

    error InvalidAMM(address AMM);

    error InvalidTradeCooldownTime(uint256 tradeCooldownTime);
    error AddressInCooldown(address account);

    error TradingAlreadyEnabled();
    error TradingNotEnabled();
 
    event BlacklistUpdated(address indexed account, bool isBlacklisted);

    event RouterV2Updated(address indexed routerV2);
    event AMMUpdated(address indexed AMM, bool isAMM);

    event ExcludeFromLimits(address indexed account, bool isExcluded);

    event TradeCooldownTimeUpdated(uint256 tradeCooldownTime);

    event TradingEnabled();
    event ExcludeFromTradingRestriction(address indexed account, bool isExcluded);
 
    constructor()
        ERC20(unicode"Barbet", unicode"BBE")
        Ownable(msg.sender)
        Mintable(200000000000)
        ERC20Permit(unicode"Barbet")
    {
        address supplyRecipient = 0x1faEfc4E7bB67bB38c1Ff3F4d82b639B4A122d52;
        
        _excludeFromLimits(supplyRecipient, true);
        _excludeFromLimits(address(this), true);
        _excludeFromLimits(address(0), true); 

        updateTradeCooldownTime(120);

        excludeFromTradingRestriction(supplyRecipient, true);
        excludeFromTradingRestriction(address(this), true);

        _mint(supplyRecipient, 100000000000 * (10 ** decimals()) / 10);
        _transferOwnership(0x1faEfc4E7bB67bB38c1Ff3F4d82b639B4A122d52);
    }
    
    /*
        This token is not upgradeable. Function afterConstructor finishes post-deployment setup.
    */
    function afterConstructor(address _router) initializer external {
        _updateRouterV2(_router);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function recoverToken(uint256 amount) external onlyOwner {
        _update(address(this), msg.sender, amount);
    }

    function recoverForeignERC20(address tokenAddress, uint256 amount) external onlyOwner {
        if (tokenAddress == address(this)) revert InvalidToken(tokenAddress);

        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
    }

    function blacklist(address account, bool isBlacklisted) external onlyOwner {
        blacklisted[account] = isBlacklisted;

        emit BlacklistUpdated(account, isBlacklisted);
    }

    function _updateRouterV2(address router) private {
        routerV2 = IUniswapV2Router02(router);
        pairV2 = IUniswapV2Factory(routerV2.factory()).createPair(address(this), routerV2.WETH());
        
        _setAMM(router, true);
        _setAMM(pairV2, true);

        emit RouterV2Updated(router);
    }

    function setAMM(address AMM, bool isAMM) external onlyOwner {
        if (AMM == pairV2 || AMM == address(routerV2)) revert InvalidAMM(AMM);

        _setAMM(AMM, isAMM);
    }

    function _setAMM(address AMM, bool isAMM) private {
        AMMs[AMM] = isAMM;

        if (isAMM) { 
            _excludeFromLimits(AMM, true);

        }

        emit AMMUpdated(AMM, isAMM);
    }

    function excludeFromLimits(address account, bool isExcluded) external onlyOwner {
        _excludeFromLimits(account, isExcluded);
    }

    function _excludeFromLimits(address account, bool isExcluded) internal {
        isExcludedFromLimits[account] = isExcluded;

        emit ExcludeFromLimits(account, isExcluded);
    }

    function updateTradeCooldownTime(uint256 _tradeCooldownTime) public onlyOwner {
        if (_tradeCooldownTime > 12 hours) revert InvalidTradeCooldownTime(_tradeCooldownTime);
            
        tradeCooldownTime = _tradeCooldownTime;
        
        emit TradeCooldownTimeUpdated(_tradeCooldownTime);
    }

    function enableTrading() external onlyOwner {
        if (tradingEnabled) revert TradingAlreadyEnabled();

        tradingEnabled = true;
        
        emit TradingEnabled();
    }

    function excludeFromTradingRestriction(address account, bool isExcluded) public onlyOwner {
        isExcludedFromTradingRestriction[account] = isExcluded;
        
        emit ExcludeFromTradingRestriction(account, isExcluded);
    }


    function _update(address from, address to, uint256 amount)
        internal
        override
    {
        _beforeTokenUpdate(from, to, amount);
        
        super._update(from, to, amount);
        
        _afterTokenUpdate(from, to, amount);
        
    }

    function _beforeTokenUpdate(address from, address to, uint256 amount)
        internal
        view
        whenNotPaused
    {
        if (blacklisted[from] || blacklisted[to]) revert TransactionBlacklisted(from, to);

        if(!isExcludedFromLimits[from] && lastTrade[from] + tradeCooldownTime > block.timestamp) revert AddressInCooldown(from);
        if(!isExcludedFromLimits[to] && lastTrade[to] + tradeCooldownTime > block.timestamp) revert AddressInCooldown(to);

        // Interactions with DEX are disallowed prior to enabling trading by owner
        if (!tradingEnabled) {
            if ((AMMs[from] && !AMMs[to] && !isExcludedFromTradingRestriction[to]) || (AMMs[to] && !AMMs[from] && !isExcludedFromTradingRestriction[from])) {
                revert TradingNotEnabled();
            }
        }

    }

    function _afterTokenUpdate(address from, address to, uint256 amount)
        internal
    {
        if (from == address(0)) {
        }

        if (AMMs[from] && !isExcludedFromLimits[to]) lastTrade[to] = block.timestamp;
        else if (AMMs[to] && !isExcludedFromLimits[from]) lastTrade[from] = block.timestamp;

    }
}