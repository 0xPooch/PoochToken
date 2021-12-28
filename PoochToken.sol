// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Pooch is ERC20, ERC20Snapshot, Ownable, ERC20Permit, ERC20Votes {
    using SafeMath for uint256;

    uint256 private _maxTokens = 1000000000 * 10**decimals(); //1 billion tokens

    bool private _paused;

    address private _burnWallet;
    address private _charityWallet;
    address private _farmWallet;
    address private _lotteryWallet;
    address private _treasuryWallet;

    address[] private _taxExempt; //accounts exempt from taxes taken in transfer

    uint256 private _burnTax;
    uint256 private _charityTax;
    uint256 private _farmTax;
    uint256 private _lotteryTax;
    uint256 private _treasuryTax;

    constructor() ERC20("Pooch", "POOCH") ERC20Permit("Pooch") {
        taxExemptionAdd(msg.sender);
        _mint(msg.sender, _maxTokens);
        _paused = false;
        _charityTax = 20000; //0.5% by default
        _lotteryTax = 20000; //0.5% by default
        _treasuryTax = 0;
        _farmTax = 0;
    }

    /*****************************************
     * GENERAL CONTRACT CONTROLS
     *****************************************/
    function pause() public onlyOwner {
        _paused = true;
    }

    function unpause() public onlyOwner {
        _paused = false;
    }

    function isPaused() public view returns (bool) {
        return _paused;
    }

    function renounceOwnership() public override onlyOwner {
        //disabling
    }

    function snapshot() public onlyOwner returns (uint256) {
        return _snapshot();
    }

    function maxSupply() public view returns (uint256) {
        return _maxTokens;
    }

    /*****************************************
     * TAX EXEMPTIONS
     *****************************************/
    function taxExemptionAdd(address account) public onlyOwner {
        uint256 i;
        for (i = 0; i < _taxExempt.length; i++) {
            if (_taxExempt[i] == account) {
                return;
            }
        }
        _taxExempt.push(account);
    }

    function taxExemptionRemove(address account) public onlyOwner {
        uint256 i;
        for (i = 0; i < _taxExempt.length; i++) {
            if (_taxExempt[i] == account) {
                delete _taxExempt[i];
                return;
            }
        }
    }

    function taxExemptAccounts() public view returns (address[] memory) {
        return _taxExempt;
    }

    function isTaxExempt(address account) public view returns (bool) {
        uint256 i;
        for (i = 0; i < _taxExempt.length; i++) {
            if (_taxExempt[i] == account) {
                return true;
            }
        }
        return false;
    }

    /*****************************************
     * WALLET GETTERS & SETTERS
     *****************************************/
    function setBurnWallet(address account) public onlyOwner {
        _burnWallet = account;
        taxExemptionAdd(account);
    }

    function setCharityWallet(address account) public onlyOwner {
        _charityWallet = account;
        taxExemptionAdd(account);
    }

    function setFarmWallet(address account) public onlyOwner {
        _farmWallet = account;
        taxExemptionAdd(account);
    }

    function setLotteryWallet(address account) public onlyOwner {
        _lotteryWallet = account;
        taxExemptionAdd(account);
    }

    function setTreasuryWallet(address account) public onlyOwner {
        _treasuryWallet = account;
        taxExemptionAdd(account);
    }

    function burnWallet() public view returns (address) {
        return _burnWallet;
    }

    function charityWallet() public view returns (address) {
        return _charityWallet;
    }

    function farmWallet() public view returns (address) {
        return _farmWallet;
    }

    function lotteryWallet() public view returns (address) {
        return _lotteryWallet;
    }

    function treasuryWallet() public view returns (address) {
        return _treasuryWallet;
    }

    /*****************************************
     * CONTROL TAXES
     *****************************************/
    function charityTaxSet(uint256 tax) public onlyOwner {
        _charityTax = tax;
    }

    function charityTax() public view returns (uint256) {
        return _charityTax;
    }

    function lotteryTaxSet(uint256 tax) public onlyOwner {
        _lotteryTax = tax;
    }

    function lotteryTax() public view returns (uint256) {
        return _lotteryTax;
    }

    function treasuryTaxSet(uint256 tax) public onlyOwner {
        _treasuryTax = tax;
    }

    function treasuryTax() public view returns (uint256) {
        return _treasuryTax;
    }

    function farmTaxSet(uint256 tax) public onlyOwner {
        _farmTax = tax;
    }

    function farmTax() public view returns (uint256) {
        return _farmTax;
    }

    function burnTaxSet(uint256 tax) public onlyOwner {
        _burnTax = tax;
    }

    function burnTax() public view returns (uint256) {
        return _burnTax;
    }

    /*****************************************
     * TOKEN TRANSFERS
     *****************************************/
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20) {
        require(_paused == false, "Pooch contract is paused.");

        uint256 _burnAmt = 0;
        uint256 _charityAmt = 0;
        uint256 _farmAmt = 0;
        uint256 _lotteryAmt = 0;
        uint256 _treasuryAmt = 0;
        uint256 _netAmt = amount;

        if (isTaxExempt(sender) == false) {
            if (_burnWallet != address(0) && _burnTax > 0) {
                _burnAmt = amount / _burnTax;
                super._transfer(sender, _burnWallet, _burnAmt);
                _netAmt = _netAmt.sub(_burnAmt);
            }

            if (_charityWallet != address(0) && _charityTax > 0) {
                _charityAmt = amount / _charityTax;
                super._transfer(sender, _charityWallet, _charityAmt);
                _netAmt = _netAmt.sub(_charityAmt);
            }

            if (_farmWallet != address(0) && _farmTax > 0) {
                _farmAmt = amount / _farmTax;
                super._transfer(sender, _farmWallet, _farmAmt);
                _netAmt = _netAmt.sub(_farmAmt);
            }

            if (_lotteryWallet != address(0) && _lotteryTax > 0) {
                _lotteryAmt = amount / _lotteryTax;
                super._transfer(sender, _lotteryWallet, _lotteryAmt);
                _netAmt = _netAmt.sub(_lotteryAmt);
            }

            if (_treasuryWallet != address(0) && _treasuryTax > 0) {
                _treasuryAmt = amount / _treasuryTax;
                super._transfer(sender, _treasuryWallet, _treasuryAmt);
                _netAmt = _netAmt.sub(_treasuryAmt);
            }
        }

        super._transfer(sender, recipient, _netAmt);
    }

    /*****************************************
     * TOKEN SUPPLY
     *****************************************/
    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        require(totalSupply() + amount <= _maxTokens);
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
