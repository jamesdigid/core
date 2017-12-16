pragma solidity 0.4.18;

import "zeppelin/ownership/Ownable.sol";
import "zeppelin/token/SafeERC20.sol";
import "zeppelin/math/SafeMath.sol";
import "zeppelin/token/ERC20.sol";
import "./AccountRegistry.sol";

contract InviteCollateralizer is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  ERC20 public blt;
  address public seizedTokensWallet;
  mapping (address => Collateralization[]) public collateralizations;
  uint256 public collateralAmount = 1e17;

  address private collateralTaker;
  address private collateralSeizer;

  struct Collateralization {
    uint256 value; // Amount of BLT
    uint64 releaseDate; // Date BLT can be withdrawn
    bool claimed; // Has the original owner or the network claimed the collateral
  }

  event CollateralPosted(address indexed owner, uint64 releaseDate, uint256 amount);
  event CollateralSeized(address indexed owner, uint256 collateralId);

  function InviteCollateralizer(ERC20 _blt, address _seizedTokensWallet) public {
    blt = _blt;
    seizedTokensWallet = _seizedTokensWallet;
    collateralTaker = owner;
    collateralSeizer = owner;
  }

  function takeCollateral(address _owner) public onlyCollateralTaker returns (bool) {
    require(blt.transferFrom(_owner, address(this), collateralAmount));

    uint64 releaseDate = uint64(now) + 1 years;
    CollateralPosted(_owner, releaseDate, collateralAmount);
    collateralizations[_owner].push(Collateralization(collateralAmount, releaseDate, false));

    return true;
  }

  function reclaim() public returns (bool) {
    require(collateralizations[msg.sender].length > 0);

    uint256 reclaimableAmount = 0;

    for (uint256 i = 0; i < collateralizations[msg.sender].length; i++) {
      if (collateralizations[msg.sender][i].claimed) {
        continue;
      } else if (collateralizations[msg.sender][i].releaseDate > now) {
        break;
      }

      reclaimableAmount = reclaimableAmount.add(collateralizations[msg.sender][i].value);
      collateralizations[msg.sender][i].claimed = true;
    }

    require(reclaimableAmount > 0);

    return blt.transfer(msg.sender, reclaimableAmount);
  }

  function seize(address _subject, uint256 _collateralId) public onlyCollateralSeizer {
    require(collateralizations[_subject].length >= _collateralId + 1);
    require(!collateralizations[_subject][_collateralId].claimed);

    collateralizations[_subject][_collateralId].claimed = true;
    blt.transfer(seizedTokensWallet, collateralizations[_subject][_collateralId].value);
    CollateralSeized(_subject, _collateralId);
  }

  function changeCollateralTaker(address _newCollateralTaker) public nonZero(_newCollateralTaker) onlyOwner {
    collateralTaker = _newCollateralTaker;
  }

  function changeCollateralSeizer(address _newCollateralSeizer) public nonZero(_newCollateralSeizer) onlyOwner {
    collateralSeizer = _newCollateralSeizer;
  }

  function changeCollateralAmount(uint256 _newAmount) public onlyOwner {
    require(_newAmount > 0);
    collateralAmount = _newAmount;
  }

  function changeSeizedTokensWallet(address _newSeizedTokensWallet) public nonZero(_newSeizedTokensWallet) onlyOwner {
    seizedTokensWallet = _newSeizedTokensWallet; 
  }

  modifier nonZero(address _address) {
    require(_address != 0);
    _;
  }

  modifier onlyCollateralTaker {
    require(msg.sender == collateralTaker);
    _;
  }

  modifier onlyCollateralSeizer {
    require(msg.sender == collateralSeizer);
    _;
  }
}
