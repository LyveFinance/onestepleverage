// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import  "@openzeppelin/contracts/access/Ownable.sol";

import "./Interfaces/IDebtToken.sol";

contract DebtFlashMint is ReentrancyGuard,Ownable {

    bytes32 private constant _RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");
    // --- Constants ---
    uint256 public constant PERCENTAGE_BASE = 10_000;
    uint256 public constant MAX_FLASH_MINT_FEE_PERCENTAGE = 500;

    uint256 public flashMintFeePercentage;
    address public feeRecipient;
    uint256 public maxFlashLoanAmount;


    IDebtToken public debtToken;

    
    event FlashMintFeePercentageChanged(uint256 flashMintFeePercentage);

    error FlashFeePercentageTooBig(uint256 feePercentage);

    constructor( address _feeRecipient,address _debtToken ){
        setFlashMintFeePercentage(PERCENTAGE_BASE / 200); // 0.5%
        feeRecipient = _feeRecipient;
        debtToken = IDebtToken(_debtToken);
    }

    function _mint(address to, uint256 amount) internal virtual{
        IDebtToken(debtToken).mintFromWhitelistedContract(amount);
        IDebtToken(debtToken).transfer(to, amount);
    }

    function _burn(address account, uint256 amount) internal virtual { 
        IDebtToken(debtToken).transferFrom(account, address(this), amount);
        IDebtToken(debtToken).burnFromWhitelistedContract(amount);
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        IDebtToken(debtToken).transferFrom(from, to, amount);
    }

    function setFlashMintFeePercentage(uint256 feePercentage) public onlyOwner {
        if (feePercentage > MAX_FLASH_MINT_FEE_PERCENTAGE) {
            revert FlashFeePercentageTooBig(feePercentage);
        }

        flashMintFeePercentage = feePercentage;
        emit FlashMintFeePercentageChanged(flashMintFeePercentage);
    }
 function setMaxFlashLoan(uint256 _maxFlashLoan) public onlyOwner {
        require(_maxFlashLoan>0,"_maxFlashLoan error");
        maxFlashLoanAmount = _maxFlashLoan;        
    }
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 loanAmount,
        bytes calldata data
    ) public virtual returns (bool) {
        require(loanAmount <= maxFlashLoan(token), "ERC20FlashMint: amount exceeds maxFlashLoan");
        uint256 fee = flashFee(token, loanAmount);
        _mint(address(receiver), loanAmount);
        require( 
            receiver.onFlashLoan(msg.sender, token, loanAmount, fee, data) == _RETURN_VALUE,
            "FlashMint: invalid return value"
        );
        address flashFeeReceiver = _flashFeeReceiver();
        if (fee == 0 || flashFeeReceiver == address(0)) {
            _burn(address(receiver), loanAmount + fee);
        } else {
            _burn(address(receiver), loanAmount);
            _transfer(address(receiver), flashFeeReceiver, fee);
        }
        return true;
    }

    /// @dev Inherited from ERC20FlashMint. Defines maximum size of the flash mint.
    /// @param token Token to be flash minted. Returns 0 amount in case of token != address(this).
    function maxFlashLoan(address token)
        public
        view
        virtual
        returns (uint256)
    {
        return token == address(debtToken) ? maxFlashLoanAmount : 0;
    }
    

     function flashFee(address token, uint256 amount) public view virtual returns (uint256) {
        require(token == address(debtToken) , "ERC20FlashMint: wrong token");
        return _flashFee(token, amount);
    }

    /// @dev Inherited from ERC20FlashMint. Defines flash mint fee for the flash mint of @param amount tokens.
    /// @param token Token to be flash minted. Returns 0 fee in case of token != address(debtToken).
    /// @param amount Size of the flash mint.
    function _flashFee(address token, uint256 amount) internal view virtual returns (uint256) {
        return token == address(debtToken) ? amount * flashMintFeePercentage / PERCENTAGE_BASE : 0;
    }

    /// @dev Inherited from ERC20FlashMint. Defines flash mint fee receiver.
    /// @return Address that will receive flash mint fees.
    function _flashFeeReceiver() internal view virtual returns (address) {
        return feeRecipient;
    }
    function totalSupply() public view virtual returns (uint256) {
        return IDebtToken(debtToken).totalSupply();
    }
 
}
