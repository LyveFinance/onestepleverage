// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../Interfaces/oracles/IPPtOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract PTeEthAggregator is AggregatorV3Interface , Ownable{


	uint256 internal constant PRECISION = 1 ether;

	uint32 public immutable twapDuration;
    address public immutable feed;
    uint8 public immutable feedDecimals;
    address public immutable ptOracle;
	address public immutable market;
    uint8 public constant significantFigures = 5;
    


    // ------------------ NOT TO INCLUDE IN PRODUCTION CODE ------------------

    error IncreaseCardinalityRequired(uint16 cardinalityRequired);
    error AdditionalWaitRequired(uint32 duration);

   constructor( address _ptOracle,address _feed,uint32 _twapDuration, address _market  ){
       ptOracle = _ptOracle;
	   twapDuration = _twapDuration;
	   feed = _feed;
	   market = _market;
	   feedDecimals = AggregatorV3Interface(feed).decimals();
   }
	function decimals() external view override returns (uint8) {
		return feedDecimals;
	}

	function description() external pure override returns (string memory) {
		return "PT-eEth2UsdPriceAggregator";
	}
	function getRoundData(uint80 _roundId)
		external
		view
		override
		returns (
			uint80 roundId,
			int256 answer,
			uint256 startedAt,
			uint256 updatedAt,
			uint80 answeredInRound
		)
	{
		( roundId,  answer, startedAt , updatedAt, answeredInRound) = AggregatorV3Interface(feed).getRoundData(_roundId);
         require(updatedAt > 0, "updatedAt cannot be zero");
		 answer = int256(_toPtPrice(uint256(answer)));
	}
	function latestRoundData()
		external
		view
		override
		returns (
			uint80 roundId,
			int256 answer,
			uint256 startedAt,
			uint256 updatedAt,
			uint80 answeredInRound
		)
	{
		( roundId,  answer, startedAt , updatedAt, answeredInRound) = AggregatorV3Interface(feed).latestRoundData();
         require(updatedAt > 0, "updatedAt cannot be zero");
		 answer = int256(_toPtPrice(uint256(answer)));
	}


	function version() external pure override returns (uint256) {
		return 1;
	}


	// Internal/Helper functions ----------------------------------------------------------------------------------------

	function _toPtPrice(uint256 underPrice) internal view returns (uint256 ) {
		require(underPrice > 0, "underPrice value cannot be zero");
		checkOracleState();
        uint256 ptRate = IPPtOracle(ptOracle).getPtToAssetRate(market, twapDuration);
		require(ptRate > 0, "ptRate cannot be zero");
        ptRate = truncateToSignificantFigures(ptRate,significantFigures);
		return (underPrice * ptRate) / PRECISION;
	}

    function truncateToSignificantFigures(uint256 value, uint256 _significantFigures) public pure returns (uint256) {
        require(_significantFigures > 0, "Significant figures must be greater than zero");
        uint256 digits = 0;
        uint256 tempValue = value;

        while (tempValue != 0) {
            digits++;
            tempValue /= 10;
        }

        if (_significantFigures >= digits) {
            return value;  
        }

    
        uint256 digitsToRemove = digits - _significantFigures;
        uint256 divisor = 10 ** digitsToRemove;

        return (value / divisor) * divisor;
    }



    /// @notice Call only once for each (market, duration). Once successful, it's permanently valid (also for any shorter duration).
    function checkOracleState() public view {
        (bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied) = IPPtOracle(
            ptOracle
        ).getOracleState(market, twapDuration);

        if (increaseCardinalityRequired) {
            // It's required to call IPMarket(market).increaseObservationsCardinalityNext(cardinalityRequired) and wait for
            // at least the twapDuration, to allow data population.
            revert IncreaseCardinalityRequired(cardinalityRequired);
        }

        if (!oldestObservationSatisfied) {
            // It's necessary to wait for at least the twapDuration, to allow data population.
            revert AdditionalWaitRequired(twapDuration);
        }
    }
}