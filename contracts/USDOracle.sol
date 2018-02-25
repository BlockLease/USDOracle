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
  uint public delay;

  event Log(string message);
  event Updated();

  function USDOracle() public {
    operators[msg.sender] = true;
    operators[address(0xddeC6C333538fCD3de7cfB56D6beed7Fd8dEE604)] = true;
    // Try to peg to 1 hour updates
    delay = 60 * 60;
    update(0);
  }

  function () payable public {
    update(0);
  }

  function priceNeedsUpdate() public constant returns (bool) {
    return block.timestamp > lastUpdated + delay;
  }

  function update(uint _delay) payable public {
    require(
      operators[msg.sender] ||
      msg.sender == oraclize_cbAddress() ||
      msg.value >= usdToWei(1)
    );
    if (oraclize_getPrice("URL") > this.balance) {
      Log("Oracle needs funds");
      return;
    }
    oraclize_query(_delay, "URL", "json(https://api.gdax.com/products/ETH-USD/ticker).price");
  }

  function usdToWei(uint _usd) public constant returns (uint256) {
    if (price == 0 || _usd == 0) return 0; // Prevent divide by 0
    return 10**18 / price * _usd * 100;
  }

  function __callback(bytes32, string _result) public {
    require(msg.sender == oraclize_cbAddress());
    price = parseInt(_result, 2);
    uint _delay = delay;
    if (
        block.timestamp - lastUpdated < _delay &&
        block.timestamp - lastUpdated >= 0
    ) {
        _delay = delay - (block.timestamp - lastUpdated);
    }
    lastUpdated = block.timestamp;
    update(_delay);
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
