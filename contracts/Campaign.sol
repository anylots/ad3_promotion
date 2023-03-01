// SPDX-License-Identifier: GPL-3.0 license

pragma solidity ^0.8.0;

import { IERC20 } from "./interfaces/IERC20.sol";
import { SafeTransferLib } from "./libs/SafeTransferLib.sol";
import { ECDSA } from "./libs/ECDSA.sol";

/**
 * @title Campaign contract
 * @dev Fund and crowd management logic of Ad3 protocol.
 * - All admin functions are callable by the ad3Hub
 * - Users can:
 *   # Query campaign remain balance
 *
 * @author Ad3
 **/
contract Campaign {
  //make the transfer lower gas-used and more safety.
  using SafeTransferLib for IERC20;

  /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

  event CreateCampaign(address indexed advertiser);

  event ClaimCpaReward(address indexed user);

  event ClaimTaskReward(address indexed user);

  event WithdrawCpaBudget(address indexed advertiser);

  event WithdrawTaskBudget(address indexed advertiser);

  /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

  // campaign only init once.
  bool private _initialized;

  // rake ratio.
  uint256 public _ratio;

  // address of ad3hub contract.
  address private _ad3hub;

  // campaign cpa budget token.
  address public _cpaPaymentToken;

  // campaign task budget token.
  address public _taskPaymentToken;

  // the ecdsa signer used to verify claim for user prizes.
  address private _trustedSigner;

  // the vault of protocol.
  address private _protocolVault;

  // the account cpa reward has claimed.
  mapping(address => bool) claimedCpaAddress;

  // the account task reward has claimed.
  mapping(address => bool) claimedTaskAddress;

  /*//////////////////////////////////////////////////////////////
                           OWNER OPERATIONS
    //////////////////////////////////////////////////////////////*/

  /**
   *@dev Throws if called by any account other than the Ad3Hub.
   */
  modifier onlyAd3Hub() {
    require(msg.sender == _ad3hub, "The caller must be ad3hub.");
    _;
  }

  /**
   * @dev Constructor.
   * @param cpaPaymentToken The list of kol
   * @param taskPaymentToken amount to be awarded to each user
   * @param trustedSigner address of paymentToken
   * @param protocolVault address of protocolVault
   * @param ratio address of paymentToken
   **/
  function init(
    address cpaPaymentToken,
    address taskPaymentToken,
    address trustedSigner,
    address protocolVault,
    uint256 ratio
  ) public {
    require(_initialized == false, "AD3: campaign is already initialized.");
    _initialized = true;

    _ad3hub = msg.sender;
    _cpaPaymentToken = cpaPaymentToken;
    _taskPaymentToken = taskPaymentToken;
    _trustedSigner = trustedSigner;
    _protocolVault = protocolVault;
    _ratio = ratio;

    emit CreateCampaign(msg.sender);
  }

  /**
   * @dev withdraw the remaining funds to advertiser.
   * @param advertiser The campaign's creater or owner
   **/
  function withdrawCpaBudget(
    address advertiser
  ) public onlyAd3Hub returns (bool) {
    uint256 balance = IERC20(_cpaPaymentToken).balanceOf(address(this));

    IERC20(_cpaPaymentToken).safeTransfer(advertiser, balance);

    emit WithdrawCpaBudget(advertiser);
    return true;
  }

  /**
   * @dev withdraw the remaining funds to advertiser.
   * @param advertiser The campaign's creater or owner
   **/
  function withdrawTaskBudget(
    address advertiser
  ) public onlyAd3Hub returns (bool) {
    uint256 balance = IERC20(_taskPaymentToken).balanceOf(address(this));

    IERC20(_taskPaymentToken).safeTransfer(advertiser, balance);

    emit WithdrawTaskBudget(advertiser);
    return true;
  }

  /*//////////////////////////////////////////////////////////////
                           USER OPERATIONS
    //////////////////////////////////////////////////////////////*/

  /**
   * @dev claim cpa user prize.
   * @param amount the cpa task reward amount
   * @param _signature ECDSA signature of cpa reward
   **/
  function claimCpaReward(uint256 amount, bytes memory _signature) external {
    require(
      claimedCpaAddress[msg.sender] == false,
      "AD3Hub: Repeated claim reward."
    );
    require(amount >= 0, "Amount invalid.");

    bytes32 _ethSignedMesssageHash = ECDSA.toEthSignedMessageHash(
      keccak256(abi.encodePacked(address(this), "CPA", msg.sender, amount))
    );

    require(
      ECDSA.verify(_ethSignedMesssageHash, _signature, _trustedSigner),
      "PrizeSignature invalid."
    );

    claimedCpaAddress[msg.sender] = true;
    uint256 _amount = amount * ((100 - _ratio) / 100);
    uint256 _rakeAmount = amount * (_ratio / 100);
    if (_amount > 0) {
      IERC20(_cpaPaymentToken).safeTransfer(msg.sender, _amount);
    }
    if (_rakeAmount > 0) {
      IERC20(_cpaPaymentToken).safeTransfer(_protocolVault, _rakeAmount);
    }

    emit ClaimCpaReward(msg.sender);
  }

  /**
   * @dev claim task user prize.
   * @param amount the task reward amount
   * @param _signature ECDSA signature of task reward
   **/
  function claimTaskReward(uint256 amount, bytes memory _signature) external {
    require(
      claimedTaskAddress[msg.sender] == false,
      "AD3Hub: Repeated claim reward."
    );
    require(amount >= 0, "AD3Hub: Amount invalid.");

    bytes32 _ethSignedMessageHash = ECDSA.toEthSignedMessageHash(
      keccak256(abi.encodePacked(address(this), "TASK", msg.sender, amount))
    );

    require(
      ECDSA.verify(_ethSignedMessageHash, _signature, _trustedSigner),
      "AD3Hub: PrizeSignature invalid."
    );

    claimedTaskAddress[msg.sender] = true;
    uint256 _amount = amount * ((100 - _ratio) / 100);
    uint256 _rakeAmount = amount * (_ratio / 100);
    if (_amount > 0) {
      IERC20(_taskPaymentToken).safeTransfer(msg.sender, _amount);
    }
    if (_rakeAmount > 0) {
      IERC20(_taskPaymentToken).safeTransfer(_protocolVault, _rakeAmount);
    }

    emit ClaimTaskReward(msg.sender);
  }

  /**
   * @dev Query campaign remain cpa balance.
   **/
  function remainCpaBonusBalance() public view returns (uint256) {
    uint256 balance = IERC20(_cpaPaymentToken).balanceOf(address(this));
    return balance;
  }

  /**
   * @dev Query campaign remain task balance.
   **/
  function remainTaskBonusBlance() public view returns (uint256) {
    uint256 balance = IERC20(_taskPaymentToken).balanceOf(address(this));
    return balance;
  }
}
