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

  /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

  // campaign only init once.
  bool private _initialized;

  // budget amount for per user.
  uint256 public _userFee;

  // address of ad3hub contract.
  address private _ad3hub;

  // campaign cpa budget token.
  address public _cpaPaymentToken;

  // campaign task budget token.
  address public _taskPaymentToken;

  // the ecdsa signer used to verify claim for user prizes.
  address private _trustedSigner;

  // the kol info saved in the storage.
  mapping(address => AD3lib.kol) private _kolStorages;

  // the account cpa reward has claimed.
  mapping(address => bool) claimedCpaAddress;

  // the account task reward has claimed.
  mapping(address => bool) claimedTaskAddress;

  uint256 public unlockTime;

  uint256 public unlockBlock;

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
   * @param kols The list of kol
   * @param userFee amount to be awarded to each user
   * @param paymentToken address of paymentToken
   **/
  function init(
    address cpaPaymentToken,
    address taskPaymentToken,
    address trustedSigner
  ) public {
    require(_initialized == false, "AD3: campaign is already initialized.");
    _initialized = true;

    _ad3hub = msg.sender;
    _cpaPaymentToken = cpaPaymentToken;
    _taskPaymentToken = taskPaymentToken;
    _trustedSigner = trustedSigner;

    emit CreateCampaign(msg.sender)
  }

  /**
   * @dev Withdraw the remaining funds to advertiser.
   * @param advertiser The campaign's creater or owner
   **/
  function withdraw(address advertiser) public onlyAd3Hub returns (bool) {
    require(
      block.timestamp >= unlockTime + 30 days,
      "Funds cannot be withdrawn yet"
    );
    unlockBlock = block.number + 172800;
    require(block.number >= unlockBlock, "Funds cannot be withdrawn yet");

    uint256 balance = IERC20(_paymentToken).balanceOf(address(this));

    IERC20(_paymentToken).safeTransfer(advertiser, balance);

    return true;
  }

  /*//////////////////////////////////////////////////////////////
                           USER OPERATIONS
    //////////////////////////////////////////////////////////////*/

  /**
   * @dev claim cpa user prize.
   * @param amount the cpa task reward amount
   * @param signature ECDSA signature of cpa reward
   **/
  function claimCpaReward(uint256 amount, bytes memory _signature) external {
    require(
      claimedCpaAddress[msg.sender] == true,
      "AD3Hub: Repeated claim reward."
    );
    require(amount <= 0, "Amount invalid.");

    bytes _ethSignedMesssageHash = ECDSA.toEthSignedMessageHash(
      keccak256(abi.encodePacked(address(this), msg.sender, amount))
    );

    require(
      verify(_ethSignedMessageHash, _signature),
      "PrizeSignature invalid."
    );

    claimedCpaAddress[msg.sender] = true;
    IERC20(_cpaPaymentToken).safeTransfer(msg.sender, amount);

    emit ClaimCpaReward(msg.sender);
  }

  /**
   * @dev claim task user prize.
   * @param amount the task reward amount
   * @param signature ECDSA signature of task reward
   **/
  function claimTaskReward(uint256 amount, bytes memory _signature) external {
    require(
      claimedTaskAddress[msg.sender] == true,
      "AD3Hub: Repeated claim reward."
    );
    require(amount <= 0, "AD3Hub: Amount invalid.");

    bytes _ethSignedMessageHash = ECDSA.toEthSignedMessageHash(
      keccak256(abi.encodePacked(address(this), msg.sender, amount))
    );

    require(
      verify(_ethSignedMessageHash, _signature),
      "AD3Hub: PrizeSignature invalid."
    );

    claimedTaskAddress[msg.sender] = true;
    IERC20(_taskPaymentToken).safeTransfer(msg.sender, amount);

    emit ClaimTaskReward(msg.sender);
  }

  /**
   * @dev Query campaign remain balance.
   **/
  function remainCpaBonusBalance() public view returns (uint256) {
    uint256 balance = IERC20(_cpaPaymentToken).balanceOf(address(this));
    return balance;
  }

  function remainTaskBonusBlance() public view returns (uint256) {
    uint256 balance = IERC20(_taskPaymentToken).balanceOf(address(this));
    return balance;
  }
}
