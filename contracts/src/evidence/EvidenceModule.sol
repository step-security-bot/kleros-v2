/**
 *  @authors: [@fnanni-0]
 *  @reviewers: []
 *  @auditors: []
 *  @bounties: []
 *  @deployments: []
 *  @tools: []
 */

pragma solidity ^0.8;

import "@kleros/erc-792/contracts/IArbitrable.sol";
import "@kleros/erc-792/contracts/erc-1497/IEvidence.sol";
import "@kleros/erc-792/contracts/IArbitrator.sol";
import "./IForeignEvidence.sol";
import "@kleros/ethereum-libraries/contracts/CappedMath.sol";

contract EvidenceModule is IArbitrable, IEvidence {
    using CappedMath for uint256;

    uint256 public constant AMOUNT_OF_CHOICES = 2;
    uint256 public constant MULTIPLIER_DIVISOR = 10000; // Divisor parameter for multipliers.

    /** Enums */

    enum Party {
        None,
        Submitter,
        Moderator
    }

    /* Structs */

    struct EvidenceData {
        address payable submitter; // Address that challenged the request.
        bool disputed; // The ID of the dispute. An evidence submission can only be disputed once.
        Party ruling;
        uint256 disputeID; //
        Moderation[] moderations;
    }

    struct Moderation {
        uint256[3] paidFees; // Tracks the fees paid by each side in this moderation.
        uint256 feeRewards; // Sum of reimbursable fees and stake rewards available to the parties that made contributions to the side that ultimately wins a dispute.
        mapping(address => uint256[3]) contributions; // Maps contributors to their contributions for each side.
        bool closed;
        Party currentWinner;
        uint256 bondDeadline;
        uint256 arbitratorDataID; // The index of the relevant arbitratorData struct.
    }

    struct ArbitratorData {
        uint256 metaEvidenceUpdates; // The meta evidence to be used in disputes.
        bytes arbitratorExtraData; // Extra data for the arbitrator.
    }

    /* Storage */

    mapping(bytes32 => EvidenceData) evidences;
    mapping(uint256 => bytes32) public disputeIDtoEvidenceID; // One-to-one relationship between the dispute and the evidence.
    ArbitratorData[] public arbitratorDataList; // Stores the arbitrator data of the contract. Updated each time the data is changed.

    IArbitrator public immutable arbitrator;
    address public governor;
    uint256 public bondTimeout;
    uint256 public totalCostMultiplier; //
    uint256 public initialDepositMultiplier;

    /* Modifiers */

    modifier onlyGovernor() {
        require(msg.sender == governor, "The caller must be the governor");
        _;
    }

    /* Events */

    /** @dev Indicate that a party has to pay a fee or would otherwise be considered as losing.
     *  @param _evidenceID The ID of the evidence being moderated.
     *  @param _currentWinner The party who is currently winning.
     */
    event ModerationStatusChanged(uint256 indexed _evidenceID, Party _currentWinner);

    constructor(
        IArbitrator _arbitrator,
        address _governor,
        bytes memory _arbitratorExtraData,
        string memory _metaEvidence
    ) {
        arbitrator = _arbitrator;
        governor = _governor;

        totalCostMultiplier = 15000;
        initialDepositMultiplier = 62; // 1/16
        bondTimeout = 24 hours;

        ArbitratorData storage arbitratorData = arbitratorDataList.push();
        arbitratorData.arbitratorExtraData = _arbitratorExtraData;
        emit MetaEvidence(0, _metaEvidence);
    }

    /** @dev Change the governor of the contract.
     *  @param _governor The address of the new governor.
     */
    function changeGovernor(address _governor) external onlyGovernor {
        governor = _governor;
    }

    /** @dev Change the proportion of arbitration fees that must be paid as fee stake by parties when there is no winner or loser (e.g. when the arbitrator refused to rule).
     *  @param _initialDepositMultiplier Multiplier of arbitration fees that must be paid as fee stake. In basis points.
     */
    function changeInitialDepositMultiplier(uint256 _initialDepositMultiplier) external onlyGovernor {
        initialDepositMultiplier = _initialDepositMultiplier;
    }

    /** @dev Change the proportion of arbitration fees that must be paid as fee stake by the winner of the previous round.
     *  @param _totalCostMultiplier Multiplier of arbitration fees that must be paid as fee stake. In basis points.
     */
    function changeTotalCostMultiplier(uint256 _totalCostMultiplier) external onlyGovernor {
        totalCostMultiplier = _totalCostMultiplier;
    }

    /** @dev Change the proportion of arbitration fees that must be paid as fee stake by the winner of the previous round.
     *  @param _bondTimeout Multiplier of arbitration fees that must be paid as fee stake. In basis points.
     */
    function changeBondTimeout(uint256 _bondTimeout) external onlyGovernor {
        bondTimeout = _bondTimeout;
    }

    /** @dev Update the meta evidence used for disputes.
     *  @param _newMetaEvidence The meta evidence to be used for future registration request disputes.
     */
    function changeMetaEvidence(string calldata _newMetaEvidence) external onlyGovernor {
        ArbitratorData storage arbitratorData = arbitratorDataList[arbitratorDataList.length - 1];
        uint256 newMetaEvidenceUpdates = arbitratorData.metaEvidenceUpdates + 1;
        arbitratorDataList.push(
            ArbitratorData({
                metaEvidenceUpdates: newMetaEvidenceUpdates,
                arbitratorExtraData: arbitratorData.arbitratorExtraData
            })
        );
        emit MetaEvidence(newMetaEvidenceUpdates, _newMetaEvidence);
    }

    /** @dev Change the arbitrator to be used for disputes that may be raised in the next requests. The arbitrator is trusted to support appeal period and not reenter.
     *  @param _arbitratorExtraData The extra data used by the new arbitrator.
     */
    function changeArbitratorExtraData(bytes calldata _arbitratorExtraData) external onlyGovernor {
        ArbitratorData storage arbitratorData = arbitratorDataList[arbitratorDataList.length - 1];
        arbitratorDataList.push(
            ArbitratorData({
                arbitrator: _arbitrator,
                metaEvidenceUpdates: arbitratorData.metaEvidenceUpdates,
                arbitratorExtraData: _arbitratorExtraData
            })
        );
    }

    function submitEvidence(uint256 _disputeID, string calldata _evidence) external payable {
        bytes32 evidenceID = keccak256(abi.encodePacked(_disputeID, _evidence));
        EvidenceData storage evidenceData = evidences[evidenceID];
        require(evidenceData.submitter == address(0x0), "Evidence already submitted.");
        evidenceData.submitter = msg.sender;

        ArbitratorData storage arbitratorData = arbitratorDataList[arbitratorDataList.length - 1];

        uint256 arbitrationCost = arbitrator.arbitrationCost(arbitratorData.arbitratorExtraData);
        uint256 totalCost = arbitrationCost.mulCap(totalCostMultiplier) / MULTIPLIER_DIVISOR;
        uint256 depositRequired = totalCost.mulCap(initialDepositMultiplier) / MULTIPLIER_DIVISOR;

        Moderation storage moderation = evidenceData.moderations.push();
        // Overpaying is allowed.
        contribute(moderation, Party.Submitter, msg.sender, msg.value, totalCost);
        require(moderation.paidFees[uint256(Party.Submitter)] >= depositRequired, "Insufficient funding.");
        moderation.bondDeadline = block.timestamp + bondTimeout;
        moderation.currentWinner = Party.Submitter;
        moderation.arbitratorDataID = arbitratorDataList.length - 1;

        // TODO: use ForeignEvidence event
        emit Evidence(arbitrator, uint256(evidenceID), msg.sender, evidence);
    }

    function moderate(bytes32 _evidenceID, Party _side) external payable {
        EvidenceData storage evidenceData = evidences[_evidenceID];
        require(evidenceData.submitter == address(0x0), "Evidence does not exist.");
        require(!evidenceData.disputed, "Evidence already disputed.");
        require(_side != Party.None, "Invalid side.");

        Moderation storage moderation = evidenceData.moderations[evidenceData.moderations.length - 1];
        if (moderation.closed) {
            // Start another round of moderation.
            moderation = evidenceData.moderations.push();
            moderation.arbitratorDataID = arbitratorDataList.length - 1;
        }
        require(_side != moderation.currentWinner, "Only the current loser can fund.");
        require(
            block.timestamp < moderation.bondDeadline || moderation.bondDeadline == 0,
            "Moderation market is closed."
        );

        ArbitratorData storage arbitratorData = arbitratorDataList[moderation.arbitratorDataID];

        uint256 arbitrationCost = arbitrator.arbitrationCost(arbitratorData.arbitratorExtraData);
        uint256 totalCost = arbitrationCost.mulCap(totalCostMultiplier) / MULTIPLIER_DIVISOR;

        uint256 opposition = 3 - uint256(_side);
        uint256 depositRequired = moderation.paidFees[opposition] * 2;
        if (depositRequired == 0) {
            depositRequired = totalCost.mulCap(initialDepositMultiplier) / MULTIPLIER_DIVISOR;
        } else if (depositRequired > totalCost) {
            depositRequired = totalCost;
        }

        // Overpaying is allowed.
        contribute(moderation, _side, msg.sender, msg.value, totalCost);
        require(moderation.paidFees[uint256(_side)] >= depositRequired, "Insufficient funding.");

        if (moderation.paidFees[uint256(_side)] >= totalCost && moderation.paidFees[opposition] >= totalCost) {
            moderation.feeRewards = moderation.feeRewards - arbitrationCost;

            evidenceData.disputeID = arbitrator.createDispute{value: arbitrationCost}(
                AMOUNT_OF_CHOICES,
                arbitratorData.arbitratorExtraData
            );
            disputeIDtoEvidenceID[evidenceData.disputeID] = _evidenceID;

            emit Dispute(arbitrator, evidenceData.disputeID, arbitratorData.metaEvidenceUpdates, _evidenceID);
            evidenceData.disputed = true;
            moderation.bondDeadline = 0;
            moderation.currentWinner = Party.None;
        } else {
            moderation.bondDeadline = block.timestamp + bondTimeout;
            moderation.currentWinner = _side;
        }
        emit ModerationStatusChanged(_evidenceID, moderation.currentWinner);
    }

    function resolveModerationMarket(bytes32 _evidenceID) external {
        // Moderation maket resolutions are not final.
        // Evidence can be reported/accepted again in the future.
        // Only an arbitrator's ruling after a dispute is final.
        EvidenceData storage evidenceData = evidences[_evidenceID];
        Moderation storage moderation = evidenceData.moderations[evidenceData.moderations.length - 1];

        require(!evidenceData.disputed, "Evidence already disputed.");
        require(block.timestamp > moderation.bondDeadline, "Moderation still ongoing.");

        moderation.closed = true;
        evidenceData.ruling = moderation.currentWinner;
    }

    /** @dev Make a fee contribution.
     *  @param _moderation The moderation to contribute to.
     *  @param _side The side to contribute to.
     *  @param _contributor The contributor.
     *  @param _amount The amount contributed.
     *  @param _totalRequired The total amount required for this side.
     *  @return The amount of fees contributed.
     */
    function contribute(
        Moderation storage _moderation,
        Party _side,
        address payable _contributor,
        uint256 _amount,
        uint256 _totalRequired
    ) internal returns (uint256) {
        uint256 contribution;
        uint256 remainingETH;
        uint256 requiredAmount = _totalRequired.subCap(_moderation.paidFees[uint256(_side)]);
        (contribution, remainingETH) = calculateContribution(_amount, requiredAmount);
        _moderation.contributions[_contributor][uint256(_side)] += contribution;
        _moderation.paidFees[uint256(_side)] += contribution;
        _moderation.feeRewards += contribution;

        if (remainingETH != 0) _contributor.send(remainingETH);

        return contribution;
    }

    /** @dev Returns the contribution value and remainder from available ETH and required amount.
     *  @param _available The amount of ETH available for the contribution.
     *  @param _requiredAmount The amount of ETH required for the contribution.
     *  @return taken The amount of ETH taken.
     *  @return remainder The amount of ETH left from the contribution.
     */
    function calculateContribution(uint256 _available, uint256 _requiredAmount)
        internal
        pure
        returns (uint256 taken, uint256 remainder)
    {
        if (_requiredAmount > _available) return (_available, 0); // Take whatever is available, return 0 as leftover ETH.

        remainder = _available - _requiredAmount;
        return (_requiredAmount, remainder);
    }

    /** @dev Withdraws contributions of moderations. Reimburses contributions if the appeal was not fully funded.
     *  If the appeal was fully funded, sends the fee stake rewards and reimbursements proportional to the contributions made to the winner of a dispute.
     *  @param _beneficiary The address that made contributions.
     *  @param _evidenceID The ID of the associated evidence submission.
     *  @param _moderationID The ID of the moderatino occurence.
     */
    function withdrawFeesAndRewards(
        address payable _beneficiary,
        uint256 _evidenceID,
        uint256 _moderationID
    ) external returns (uint256 reward) {
        EvidenceData storage evidenceData = evidences[_evidenceID];
        Moderation storage moderation = evidenceData.moderations[_moderationID];
        require(moderation.closed, "Moderation must be closed.");

        uint256[3] storage contributionTo = moderation.contributions[_beneficiary];

        if (evidenceData.disputed && evidenceData.ruling == Party.None) {
            // Reimburse unspent fees proportionally if there is no winner and loser.
            uint256 totalFeesPaid = moderation.paidFees[uint256(Party.Submitter)] +
                moderation.paidFees[uint256(Party.Moderator)];
            uint256 totalBeneficiaryContributions = contributionTo[uint256(Party.Submitter)] +
                contributionTo[uint256(Party.Moderator)];
            reward = totalFeesPaid > 0 ? (totalBeneficiaryContributions * moderation.feeRewards) / totalFeesPaid : 0;
        } else {
            // Reward the winner.
            uint256 paidFees = moderation.paidFees[uint256(evidenceData.ruling)];
            reward = paidFees > 0
                ? (contributionTo[uint256(evidenceData.ruling)] * moderation.feeRewards) / paidFees
                : 0;
        }
        contributionTo[uint256(Party.Submitter)] = 0;
        contributionTo[uint256(Party.Moderator)] = 0;

        _beneficiary.send(reward); // It is the user responsibility to accept ETH.
    }

    /** @dev Give a ruling for a dispute. Must be called by the arbitrator to enforce the final ruling.
     *  The purpose of this function is to ensure that the address calling it has the right to rule on the contract.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _ruling Ruling given by the arbitrator. Note that 0 is reserved for "Not able/wanting to make a decision".
     */
    function rule(uint256 _disputeID, uint256 _ruling) public override {
        bytes32 evidenceID = disputeIDtoEvidenceID[_disputeID];
        EvidenceData storage evidenceData = evidences[evidenceID];
        Moderation storage moderation = evidenceData.moderations[evidenceData.moderations.length - 1];
        require(
            evidenceData.disputed &&
                !moderation.closed &&
                msg.sender == address(arbitrator) &&
                _ruling <= AMOUNT_OF_CHOICES,
            "Ruling can't be processed."
        );

        evidenceData.ruling = Party(_ruling);
        moderation.closed = true;

        emit Ruling(arbitrator, _disputeID, ruling);
    }

    // **************************** //
    // *     Constant getters     * //
    // **************************** //

    /** @dev Gets the number of moderation events of the specific evidence submission.
     *  @param _evidenceID The ID of the evidence submission.
     *  @return The number of moderations.
     */
    function getNumberOfModerations(bytes32 _evidenceID) external view returns (uint256) {
        EvidenceData storage evidenceData = evidences[_evidenceID];
        return evidenceData.moderations.length;
    }

    /** @dev Gets the contributions made by a party for a given moderation.
     *  @param _evidenceID The ID of the evidence submission.
     *  @param _moderationID The ID of the moderatino occurence.
     *  @param _contributor The address of the contributor.
     *  @return contributions The contributions.
     */
    function getContributions(
        bytes32 _evidenceID,
        uint256 _moderationID,
        address _contributor
    ) external view returns (uint256[3] memory contributions) {
        EvidenceData storage evidenceData = evidences[_evidenceID];
        Moderation storage moderation = evidenceData.moderations[_moderationID];
        contributions = moderation.contributions[_contributor];
    }

    /** @dev Gets the information of a moderation event.
     *  @param _evidenceID The ID of the evidence submission.
     *  @param _moderationID The ID of the moderatino occurence.
     *  @return paidFees currentWinner feeRewards The moderation information.
     */
    function getModerationInfo(bytes32 _evidenceID, uint256 _moderationID)
        external
        view
        returns (
            uint256[3] memory paidFees,
            Party currentWinner,
            uint256 feeRewards
        )
    {
        EvidenceData storage evidenceData = evidences[_evidenceID];
        Moderation storage moderation = evidenceData.moderations[_moderationID];
        return (moderation.paidFees, moderation.currentWinner, moderation.feeRewards);
    }
}