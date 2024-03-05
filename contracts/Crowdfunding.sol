// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import '@openzeppelin/contracts/access/Ownable.sol';

contract Crowdfunding is Ownable {
  enum Status {
    inProgress,
    success,
    fail
  }

  struct Project {
    uint id;
    /**
     * @notice 项目名称
     */
    string name;
    // 项目介绍
    string desc;
    // 项目创建者
    address creator;
    // 目标金额
    uint256 goalAmount;
    // 已筹集金额
    uint256 raisedAmount;
    // 状态
    Status status;
    // 截至时间
    uint deadline;
  }

  uint _projectTotal;

  /**
   * @notice 手续费，百分比
   */
  uint8 public handlingFee;

  // 所有项目
  mapping(uint => Project) projects;

  // 存储每个项目每位捐款人的捐款金额
  mapping(uint => mapping(address => uint)) projectContributions;
  // 捐款人每个项目的捐款金额
  mapping(address => mapping(uint => uint)) contributions;

  // 存储每个项目总捐款人数
  mapping(uint => uint) totalContributorsCount;

  // 捐款事件，记录捐款人和金额
  event FundingReceived(address indexed contributor, uint indexed id, uint256 amount);
  // 项目关闭事件，记录总筹集金额
  event ProjectSuccess(uint indexed id, uint256 totalAmountRaised);

  constructor(uint8 _handlingFee) Ownable(msg.sender) {
    handlingFee = _handlingFee;
  }

  function createCrowdfunding(
    string calldata name,
    uint goalAmount,
    uint deadline,
    string calldata desc
  ) public {
    require(bytes(name).length > 0, 'Name cannot be empty');
    require(goalAmount > 0 ether, 'Target amount must be greater than 0 ether');
    require(deadline > block.timestamp, 'The deadline must be greater than the current time');

    Project memory project;
    project.id = _projectTotal;
    project.name = name;
    project.creator = msg.sender;
    project.desc = desc;
    project.goalAmount = goalAmount;
    project.deadline = deadline;
    project.status = Status.inProgress;

    projects[_projectTotal] = project;
    _projectTotal++;
  }

  function contribute(uint id) external payable {
    require(projects[id].status != Status.success, 'The project has been crowdfunded');
    require(msg.value > 0, 'Donation amount must be greater than zero');

    Project storage project = projects[id];
    project.raisedAmount += msg.value;

    emit FundingReceived(msg.sender, id, msg.value);

    if (project.raisedAmount >= project.goalAmount) {
      project.status = Status.success;
      emit ProjectSuccess(id, project.raisedAmount);
    }

    if (contributions[msg.sender][id] == 0) {
      totalContributorsCount[id]++;
    }

    contributions[msg.sender][id] += msg.value;
  }

  /**
   * @notice 获取指定捐款人的捐款金额
   * @param contributor 捐款人
   */
  function getContributionAmount(address contributor) external view returns (uint amount) {
    for (uint256 i = 0; i <= _projectTotal; i++) {
      amount += contributions[contributor][i];
    }
  }

  /**
   * @notice 获取指定项目和捐款人的捐款金额
   * @param contributor 捐款人
   * @param id 项目 id
   */
  function getContributionAmount(address contributor, uint id) external view returns (uint256) {
    return contributions[contributor][id];
  }

  /**
   * @notice 提取众筹资金
   * @param id 项目 id
   */
  function withdraw(uint id) external {
    require(projects[id].status == Status.success, 'Crowdfunding has not been completed yet');
    require(msg.sender == projects[id].creator, 'Only project creators can advance funds');

    require(projects[id].raisedAmount > 0, 'Funds withdrawn');

    uint fee = (projects[id].raisedAmount * handlingFee) / 100;
    payable(msg.sender).transfer(projects[id].raisedAmount - fee);
    payable(owner()).transfer(fee);

    projects[id].raisedAmount = 0;
  }

  /**
   * @notice 退款
   */
  function refund(uint id) external {
    require(projects[id].status != Status.success, 'Crowdfunding has been successful, No refunds allowed');

    require(contributions[msg.sender][id] > 0, 'This project has not been crowdfunded');

    payable(msg.sender).transfer(contributions[msg.sender][id]);
    contributions[msg.sender][id] = 0;
  }

  /**
   * @notice 众筹失败
   */
  function checkDeadline() external onlyOwner {
    for (uint i = 0; i <= _projectTotal; i++) {
      if (projects[i].status == Status.inProgress && projects[i].deadline > block.timestamp) {
        projects[i].status = Status.fail;
      }
    }
  }
}
