// SPDX-License-Identifier: GPL-3.0 license

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Campaign.sol";

/**
 * @title AD3Hub contract
 * @dev Main point of interaction with an Ad3 protocol's campaign manage
 * - Advertisers can:
 *   # CreateCampaign
 *   # GetCampaignAddress
 * - Owner can:
 *   # PayfixFee
 *   # Pushpay
 *   # Withdraw
 * - All admin functions are callable by the deployer
 *
 * @author Ad3
 **/
contract AD3Hub is Ownable {
  //make the transfer lower gas-used and more safety.
  using SafeTransferLib for IERC20;

  /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

  // createCampaign & claimRward transaction fee ratio
  uint256 public _ratio;

  // The ecdsa signer used to verify claim for user prizes
  address public _trustedSigner;

  // Logical implementation of campaign
  address private _campaignImpl;

  // Mapping from Advertiser address to campaign addresses
  mapping(address => mapping(uint64 => address)) private campaigns;

  // Mapping from campaign address to the lastest campaignId,
  // campaignId should be incremented from 1.
  mapping(address => uint64) private campaignIds;

  /*//////////////////////////////////////////////////////////////
                        ADVERTISER OPERATIONS
    //////////////////////////////////////////////////////////////*/

  /**
   * @dev Create an campaign with Minimal Proxy.
   * @param cpaBonusBudget cpa task bonus total budget
   * @param taskBonusBudget normal task bonus total budget
   * @param cpaPaymentToken cpa bonus token contract address
   * @param taskPaymentToken task bonus token contract address
   **/
  function createCampaign(
    uint256 cpaBonusBudget,
    uint256 taskBonusBudget,
    address cpaPaymentToken,
    address taskPaymentToken
  ) external returns (address instance) {
    require(cpaBonusBudget >= 0, "AD3Hub: cpa bonus budget less than zero.");
    require(taskBonusBudget >= 0, "AD3Hub: task bonus budget less than zero.");
    require(
      cpaPaymentToken != address(0),
      "AD3Hub: cpa token address is zero."
    );
    require(
      taskPaymentToken != address(0),
      "AD3Hub: task token address is zero."
    );

    bytes20 impl = bytes20(_campaignImpl);

    /// @solidity memory-safe-assembly
    assembly {
      // Load free memory point.
      let proxy := mload(0x40)
      // Copying runtime code into memory, get the calldata, prepare input and output parmeter.
      mstore(
        proxy,
        0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
      )
      // Copying impl address into memory.
      mstore(add(proxy, 0x14), impl)
      // Delegating the call.
      mstore(
        add(proxy, 0x28),
        0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
      )
      instance := create(0, proxy, 0x37)
    }
    require(instance != address(0), "ERC1167: campaign create failed.");

    // init campaign
    Campaign(instance).init(
      cpaPaymentToken,
      taskPaymentToken,
      _trustedSigner,
      _ratio
    );
    // init cpa amount
    IERC20(cpaPaymentToken).safeTransferFrom(
      msg.sender,
      instance,
      cpaBonusBudget
    );
    // init task amount
    IERC20(taskPaymentToken).safeTransferFrom(
      msg.sender,
      instance,
      taskBonusBudget
    );

    // save campaign to mapping
    uint64 lastest = campaignIds[msg.sender];
    lastest++;
    campaigns[msg.sender][lastest] = instance;
    campaignIds[msg.sender] = lastest;
  }

  /*//////////////////////////////////////////////////////////////
                           OWNER OPERATIONS
    //////////////////////////////////////////////////////////////*/

  /**
   * @dev Withdraw the remaining funds to advertiser.
   * @param advertiser The campaign's creater or owner
   * @param campaignId index in advertiser's campaign list
   **/
  function WithdrawCpaBudget(
    address advertiser,
    uint64 campaignId
  ) external onlyOwner {
    require(advertiser != address(0), "AD3Hub: advertiser is zero address.");

    require(
      campaigns[advertiser][campaignId] != address(0),
      "AD3Hub: No such campaign"
    );

    bool withdrawSuccess = Campaign(campaigns[advertiser][campaignId])
      .WithdrawCpaBudget(advertiser);
    require(withdrawSuccess, "AD3: withdraw failured.");
  }

  /**
   * @dev Withdraw the remaining funds to advertiser.
   * @param advertiser The campaign's creater or owner
   * @param campaignId index in advertiser's campaign list
   **/
  function WithdrawTaskBudget(
    address advertiser,
    uint64 campaignId
  ) external onlyOwner {
    require(advertiser != address(0), "AD3Hub: advertiser is zero address.");

    require(
      campaigns[advertiser][campaignId] != address(0),
      "AD3Hub: No such campaign"
    );

    bool withdrawSuccess = Campaign(campaigns[advertiser][campaignId])
      .WithdrawTaskBudget(advertiser);
    require(withdrawSuccess, "AD3: withdraw failured.");
  }

  /**
   * @dev Set trustedSigner of campaign.
   * @param trustedSigner address of trustedSigner
   **/
  function setTrustedSigner(address trustedSigner) external onlyOwner {
    require(
      trustedSigner != address(0),
      "AD3Hub: trustedSigner is zero address."
    );
    _trustedSigner = trustedSigner;
  }

  /**
   * @dev Get trustedSigner of campaign.
   * @return trustedSigner address of trustedSigner
   **/
  function getTrustedSigner() external view returns (address) {
    return _trustedSigner;
  }

  /**
   * @dev Set tranasation fee ratio of campagin
   * @param ratio transaction fee ratio
   */
  function setRatio(ratio) external onlyOwner {
    _ratio = ratio;
  }

  /**
   * @dev Get tranasation fee ratio of campagin.
   * @return ratio transaction fee ratio
   **/
  function getTrustedSigner() external view returns (address) {
    return _ratio;
  }

  /**
   * @dev Set address of campaignImpl.
   * @param campaign address of campaignImpl
   **/
  function setCampaignImpl(address campaign) external onlyOwner {
    require(campaign != address(0), "AD3Hub: campaignImpl is zero address.");
    _campaignImpl = campaign;
  }

  /*//////////////////////////////////////////////////////////////
                        PUBLIC OPERATIONS
    //////////////////////////////////////////////////////////////*/

  /**
   * @dev claim cpa user prize.
   * @param advertiser
   * @param campaignId
   * @param amount
   * @param _signature
   **/
  function claimCpaReward(
    address advertiser,
    address campainId,
    uint256 amount,
    bytes memory _signature
  ) external {
    require(advertiser != address(0), "AD3Hub: advertiser is zero address.");
    require(
      campaigns[advertiser][campaignId] != address(0),
      "AD3Hub: No such campaign"
    );
    Campaign(campaigns[advertiser][campaignId]).claimCpaReward(
      amount,
      _signature
    );
  }

  /**
   * @dev claim cpa user prize.
   * @param advertiser
   * @param campaignId
   * @param amount
   * @param _signature
   **/
  function claimTaskReward(
    address advertiser,
    address campainId,
    uint256 amount,
    bytes memory _signature
  ) external {
    require(advertiser != address(0), "AD3Hub: advertiser is zero address.");
    require(
      campaigns[advertiser][campaignId] != address(0),
      "AD3Hub: No such campaign"
    );
    Campaign(campaigns[advertiser][campaignId]).claimTaskReward(
      amount,
      _signature
    );
  }

  /**
   * @dev get Address of Campaign
   * @param advertiser The address of the advertiser who create campaign
   **/
  function getCampaignAddress(
    address advertiser,
    uint64 campaignId
  ) public view returns (address) {
    require(advertiser != address(0), "AD3Hub: advertiser is zero address.");
    return campaigns[advertiser][campaignId];
  }

  /**
   * @dev get Address list of Campaign
   * @param advertiser The address list of the advertiser who create campaign
   **/
  function getCampaignAddressList(
    address advertiser
  ) public view returns (address[] memory) {
    require(advertiser != address(0), "AD3Hub: advertiser is zero address.");
    uint64 lastest = campaignIds[advertiser];
    address[] memory campaignList;
    if (lastest == 0) {
      return campaignList;
    }
    campaignList = new address[](lastest);
    for (uint64 i = 0; i < lastest; ++i) {
      campaignList[i] = campaigns[advertiser][i + 1];
    }
    return campaignList;
  }
}
