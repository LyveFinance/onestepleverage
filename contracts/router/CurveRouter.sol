
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../Interfaces/ICurveRouter.sol";
import "../Interfaces/IAMM.sol";
 
contract CurveRouter is IAMM,Ownable {

  ICurveRouter public immutable amm;
  address public oneStepLeverage;

  constructor(address _amm,address _oneStepLeverage){
    oneStepLeverage = _oneStepLeverage;
    amm = ICurveRouter(_amm);
  }

  function setAddress(address _oneStepLeverage) public onlyOwner {
    	oneStepLeverage = _oneStepLeverage;
  }
  
  function swap(address tokenIn,address tokenOut, bytes calldata _ammData) external payable  returns (uint256 amountOut){
      require(msg.sender == oneStepLeverage,"not oneStepLeverage");
      (address[11] memory _router, uint256[5][5] memory _swap_params,uint256 _amount,uint256 _expected,address[5] memory _pools) = abi.decode(_ammData,(address[11], uint256[5][5] ,uint256 ,uint256 ,address[5] ));
        IERC20(tokenIn).transferFrom(msg.sender,address(this),_amount);
        IERC20(tokenIn).approve(address(amm),_amount);
        uint256 leveragedCollateralChange = amm.exchange(_router, _swap_params, _amount, _expected, _pools);
        IERC20(tokenOut).transfer(msg.sender,leveragedCollateralChange);
      return leveragedCollateralChange;
    }
        
}