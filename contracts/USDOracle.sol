pragma solidity ^0.4.18;

import "./oraclizeAPI_0.5.sol";

interface ERC20Contract {
  function transfer(address _to, uint256 _value) external returns (bool);
}

contract USDOracle is usingOraclize {

  /**
   * Price in cents as returned by the gdax api
   * https://www.gdax.com/trade/ETH-USD
   **/
  uint256 public price;
  uint256 public lastUpdated;
  mapping (address => bool) public operators;
  uint public delay;

  bool public queryQueued;

  event Log(string message);
  event Updated();

  /**
   * Initialize the oracle and make the contract creator the first operator.
   *
   * Set the delay and call the first update.
   *
   * Funds need to be supplied for subsequent operation.
   **/
  function USDOracle() public {
    operators[msg.sender] = true;
    // Try to peg to 1 hour updates
    delay = 60 * 5;
    update(0);
  }

  /**
   * Add funds to the oracle.
   *
   * Funds cannot be withdrawn.
   **/
  function () payable public {
    update(0);
  }

  /**
   * Schedules an update _delay seconds in the future. This function is
   * idempotent.
   *
   * This function is a no-op if queryQueued is true to prevent excessive use
   * of contract eth.
   *
   * This function is a no-op if the contract balance is not sufficient to
   * schedule the URL request.
   **/
  function update(uint _delay) public {
    require(
      operators[msg.sender] ||
      msg.sender == oraclize_cbAddress() ||
      msg.value >= usdToWei(1)
    );
    if (oraclize_getPrice("URL") > this.balance) {
      Log("Oracle needs funds");
      return;
    } else if (queryQueued) {
      Log("Oracle query already queued");
      return;
    }
    oraclize_query(_delay, "URL", "json(https://api.gdax.com/products/ETH-USD/ticker).price");
    queryQueued = true;
  }

  /**
   * Oraclize callback
   **/
  function __callback(bytes32, string _result) public {
    require(msg.sender == oraclize_cbAddress());
    queryQueued = false;
    price = parseInt(_result, 2);
    lastUpdated = block.timestamp;
    update(delay);
  }

  /**
   * A boolean for use in other contracts to halt execution if the oracle
   * becomes at of sync by (delay + 120) seconds.
   *
   * Throwing based on this function should be safe as the 120 second buffer
   * accounts for network congestion so it should always be true unless the
   * oracle is unfunded.
   **/
  function priceNeedsUpdate() public constant returns (bool) {
    return block.timestamp > lastUpdated + delay + 120;
  }

  /**
   * Helper function for working with USD
   **/
  function usdToWei(uint _usd) public constant returns (uint256) {
    if (price == 0 || _usd == 0) return 0; // Prevent divide by 0
    return 10**18 / price * _usd * 100;
  }

  /**
   * Administration, ensure a cold stored key is kept as an operator.
   **/
  modifier operator() {
    require(operators[msg.sender]);
    _;
  }

  function addOperator(address _operator) public operator {
    operators[_operator] = true;
  }

  function removeOperator(address _operator) public operator {
    operators[_operator] = false;
  }

  /**
   * For withdrawing any ERC20's sent to this address
   **/
  function withdrawERC20(
    address _tokenAddress,
    address _to,
    uint256 _value
  ) public operator {
    ERC20Contract(_tokenAddress).transfer(_to, _value);
  }

}
