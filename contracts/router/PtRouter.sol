
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../Interfaces/ICurveRouter.sol";
import "../Interfaces/IAMM.sol";
 import "../Interfaces/IPtRouter.sol";



contract PtRouter is IAMM,Ownable {

  IPtRouter public immutable ptAmm;
  ICurveRouter public immutable curveAmm;

  address public  oneStepLeverage;

  constructor( address _ptAmm,address _curveAmm,address _oneStepLeverage){
       ptAmm = IPtRouter(_ptAmm) ;
       curveAmm = ICurveRouter(_curveAmm) ;
       oneStepLeverage = _oneStepLeverage;
    }
    function setAddress(address _oneStepLeverage) public onlyOwner {
    	oneStepLeverage = _oneStepLeverage;
    }
  
    function swap(address tokenIn,address tokenOut,bytes calldata _ammData) external  payable returns (uint256 ) {
      
      require(msg.sender == oneStepLeverage,"not oneStepLeverage");

      (bytes memory cureAmmData,address tempToken,bytes memory ptAmmData) = abi.decode(_ammData,(bytes,address, bytes));
      uint256 leveragedCollateralChange = _swapCurve(tokenIn,cureAmmData);
      return _swapPt( tempToken, leveragedCollateralChange , tokenOut,  ptAmmData);
    }

    function _swapCurve(address tokenIn ,bytes memory _ammData) internal returns (uint256 ){
      
      (address[11] memory _router, uint256[5][5] memory _swap_params,uint256 _amount,uint256 _expected,address[5] memory _pools) = abi.decode(_ammData,(address[11], uint256[5][5] ,uint256 ,uint256 ,address[5] ));
        
        IERC20(tokenIn).transferFrom(msg.sender,address(this),_amount);

        IERC20(tokenIn).approve(address(curveAmm),_amount);

        return curveAmm.exchange(_router, _swap_params, _amount, _expected, _pools);

      
    }
    function _swapPt(address tokenIn,uint256 tokenInAmount ,address tokenOut,bytes memory _ammData) internal returns (uint256 ){
    
      ( ,address market,uint256 minPtOut,ApproxParams memory guessPtOut,TokenInput memory input, LimitOrderData memory limit) = abi.decode(_ammData,(address , address ,uint256 ,ApproxParams  ,TokenInput  ,LimitOrderData  ));
        
        require(tokenInAmount >=input.netTokenIn ,"pt amm netTokenIn error ");
        input.netTokenIn = tokenInAmount;
        require(input.tokenIn == tokenIn,"tokenIn error ");
        IERC20(input.tokenIn).approve(address(ptAmm),tokenInAmount);
        (uint256 netPtOut,  ,  ) = ptAmm.swapExactTokenForPt(msg.sender, market, minPtOut, guessPtOut, input,limit);
         IERC20(tokenOut).transfer(msg.sender,netPtOut);
        return netPtOut;
      
    }

      
        
}