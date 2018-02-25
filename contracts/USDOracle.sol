pragma solidity ^0.4.18;

import "./oraclizeAPI_0.5.sol";

interface ERC20Contract {
  function transfer(address _to, uint256 _value) external returns (bool);
}

contract USDOracle is usingOraclize {

  // Price in cents as returned by the gdax api
  // GDAX is an fdic insured US based exchange
  // https://www.gdax.com/trade/ETH-USD
  uint256 public price;
  uint256 public lastUpdated;
  mapping (address => bool) public operators;
  bool public priceNeedsUpdate;

  event Log(string message);
  event Updated();

  function USDOracle() public {
    operators[msg.sender] = true;
    operators[oraclize_cbAddress()] = true;
    priceNeedsUpdate = true;
    oraclize_query("URL", "json(https://api.gdax.com/products/ETH-USD/ticker).price");
  }

  function () payable public { }

  function update(uint _delay) payable public {
    require(operators[msg.sender]);
    if (oraclize_getPrice("URL") > this.balance) {
      Log("Oracle needs funds");
      priceNeedsUpdate = true;
      return;
    }
    oraclize_query(_delay, "URL", "json(https://api.gdax.com/products/ETH-USD/ticker).price");
  }

  function getPrice() public constant returns (uint256) {
    return price;
  }

  function usdToWei(uint _usd) public constant returns (uint256) {
    return 10**18 / getPrice() * _usd * 100;
  }

  function __callback(bytes32, string _result) public {
    require(msg.sender == oraclize_cbAddress());
    price = parseInt(_result, 2);
    // Try to peg to 1 hour
    uint _delay = 60 * 60;
    if (
        block.timestamp - lastUpdated < _delay &&
        block.timestamp - lastUpdated >= 0
    ) {
        _delay = block.timestamp - lastUpdated;
    }
    lastUpdated = block.timestamp;
    update(_delay);
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
    require(operators[msg.sender] && msg.sender != oraclize_cbAddress());
    ERC20Contract(_tokenAddress).transfer(_to, _value);
  }

}
