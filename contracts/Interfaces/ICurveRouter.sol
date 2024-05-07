// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface ICurveRouter {

    function exchange(address[11] memory _router, uint256[5][5] memory _swap_params,uint256 _amount,uint256 _expected,address[5] memory _pools) external  returns (uint256 );
    
}