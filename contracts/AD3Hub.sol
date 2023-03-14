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
 * - Protocol Owner can:
 *   # withdraw funds to advertiser
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

  // GMV
  mapping(address => uint64) private gmvPool;

  /*//////////////////////////////////////////////////////////////
                        EVENT
    //////////////////////////////////////////////////////////////*/

  event CreateCampaign(address indexed advertiser, address campaign, uint256 campaignId);

  /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

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
    uint256 campaignId,
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
      super.owner(),
      _ratio
    );
    // prepare cpa budget
    uint256 _cpaBonusBudget = cpaBonusBudget * (100 - _ratio) / 100;
    uint256 _cpaRakeBudget = cpaBonusBudget * _ratio / 100;
    IERC20(cpaPaymentToken).safeTransferFrom(
      msg.sender,
      instance,
      _cpaBonusBudget
    );
    // pay cpa protocol fee
    IERC20(cpaPaymentToken).safeTransferFrom(
      msg.sender,
      super.owner(),
      _cpaRakeBudget
    );
    // prepare task budget
    uint256 _taskBonusBudget = taskBonusBudget * (100 - _ratio) / 100;
    uint256 _taskRakeBudget = taskBonusBudget * _ratio / 100;
    IERC20(taskPaymentToken).safeTransferFrom(
      msg.sender,
      instance,
      _taskBonusBudget
    );
    // pay task protocol fee
    IERC20(taskPaymentToken).safeTransferFrom(
      msg.sender,
      super.owner(),
      _taskRakeBudget
    );

    // save campaign to mapping
    uint64 lastest = campaignIds[msg.sender];
    lastest++;
    campaigns[msg.sender][lastest] = instance;
    campaignIds[msg.sender] = lastest;

    emit CreateCampaign(msg.sender, instance, campaignId);
  }

  /*//////////////////////////////////////////////////////////////
                           OWNER OPERATIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Withdraw the remaining funds to advertiser.
   * @param advertiser The campaign's creater or owner
   * @param campaignId index in advertiser's campaign list
   **/
  function withdrawCpaBudget(
    address advertiser,
    uint64 campaignId
  ) external onlyOwner {
    require(advertiser != address(0), "AD3Hub: advertiser is zero address.");

    require(
      campaigns[advertiser][campaignId] != address(0),
      "AD3Hub: No such campaign"
    );

    bool withdrawSuccess = Campaign(campaigns[advertiser][campaignId])
      .withdrawCpaBudget(advertiser);
    require(withdrawSuccess, "AD3: withdraw failured.");
  }

  /**
   * @dev Withdraw the remaining funds to advertiser.
   * @param advertiser The campaign's creater or owner
   * @param campaignId index in advertiser's campaign list
   **/
  function withdrawTaskBudget(
    address advertiser,
    uint64 campaignId
  ) external onlyOwner {
    require(advertiser != address(0), "AD3Hub: advertiser is zero address.");

    require(
      campaigns[advertiser][campaignId] != address(0),
      "AD3Hub: No such campaign"
    );

    bool withdrawSuccess = Campaign(campaigns[advertiser][campaignId])
      .withdrawTaskBudget(advertiser);
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
  function setRatio(uint256 ratio) external onlyOwner {
    _ratio = ratio;
  }

  /**
   * @dev Get tranasation fee ratio of campagin.
   * @return ratio transaction fee ratio
   **/
  function getRatio() external view returns (uint256) {
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
