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

  function USDOracle() public {
    operators[msg.sender] = true;
    // Try to peg to 1 hour updates
    delay = 60 * 5;
    update(0);
  }

  function () payable public {
    update(0);
  }

  function priceNeedsUpdate() public constant returns (bool) {
    /**
     * Add a 2 minute buffer to prevent errors in dependant contracts in times
     * of network congestion
     **/
    return block.timestamp > lastUpdated + delay + 120;
  }

  /**
   * Schedules an update _delay seconds in the future.
   *
   * This function is a no-op if queryQueued is true to prevent excessive use
   * of contract eth.
   *
   * This function is a no-op if the contract balance is not sufficient to
   * schedule the URL request.
   **/
  function update(uint _delay) payable public {
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

  function usdToWei(uint _usd) public constant returns (uint256) {
    if (price == 0 || _usd == 0) return 0; // Prevent divide by 0
    return 10**18 / price * _usd * 100;
  }

  function __callback(bytes32, string _result) public {
    require(msg.sender == oraclize_cbAddress());
    queryQueued = false;
    price = parseInt(_result, 2);
    lastUpdated = block.timestamp;
    update(delay);
  }

  function addOperator(address _operator) public {
    require(operators[msg.sender]);
    operators[_operator] = true;
  }

  function removeOperator(address _operator) public {
    require(operators[msg.sender]);
    operators[_operator] = false;
  }

  /**
   * For withdrawing any tokens sent to this address
   *
   **/
  function withdrawERC20(
    address _tokenAddress,
    address _to,
    uint256 _value
  ) public {
    require(operators[msg.sender]);
    ERC20Contract(_tokenAddress).transfer(_to, _value);
  }

}
