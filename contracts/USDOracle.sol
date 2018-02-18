pragma solidity ^0.4.19;

import "./oraclizeAPI_0.4.sol";

interface ERC20Contract {
  transfer(address _to, uint256 _value) returns (bool success);
}

contract USDOracle is usingOraclize {

  // Price in cents as returned by the gdax api
  // GDAX is an fdic insured US based exchange
  // https://www.gdax.com/trade/ETH-USD
  uint256 price;
  uint lastUpdated = 0;
  // Price is valid for 1 hour
  uint public priceExpirationInterval = 21600;
  address owner;

  function USDOracle() public {
    owner = msg.sender;
    update();
  }

  function update() payable {
    require(msg.value >= usdToWei(1));
    oraclize_query("URL","json(https://api.gdax.com/products/ETH-USD/ticker).price");
  }

  function usdToWei(uint _usd) public constant returns (uint256) {
    return 10**18 / getPrice() * _usd * 100;
  }

  function getPrice() public constant returns (uint256) {
    return price;
  }

  function priceNeedsUpdate() public constant returns (bool) {
    return block.timestamp > (lastUpdated + priceExpirationInterval);
  }

  function __callback(bytes32 _myid, string _result) public {
    require(msg.sender == oraclize_cbAddress());
    price = parseInt(_result, 2);
    lastUpdated = block.timestamp;
  }

  function withdraw(address _to) public {
    require(msg.sender == owner);
    _to.transfer(this.balance);
  }

  /**
   * For withdrawing any tokens sent to this address
   *
   **/
  function transferERC20(address tokenAddress, address to, uint256 value) {
    require(msg.sender == owner);
    ERC20Contract(tokenAddress).transfer(to, value);
  }

}
