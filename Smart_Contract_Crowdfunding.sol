// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Project: SmartFund

contract DIDRegistry {
    struct DID {
        string identifier;
        address owner;
        string status; // "active", "suspended", "deactivated"
        bool verified; // Whether the DID is verified
    }

    struct Metadata {
        string name;
        string email;
        string profilePicture;
        string location;
        string socialMediaLinks;
        string biography;
    }

    struct Campaign {
        string title;
        string description;
        address owner;
        uint goalAmount;
        uint amountRaised;
        bool isActive;
        uint createdAt;
        string status; // "pending", "active", "completed", "closed"
    }

    struct Contribution {
        address contributor;
        uint amount;
        uint timestamp;
        bool refunded; // Track if the contribution has been refunded
    }

    mapping(address => DID) private dids;
    mapping(address => Metadata) private metadata;
    mapping(address => string[]) private roles;
    mapping(address => string[]) private roleHistory;

    mapping(uint => Campaign) private campaigns; // Campaign ID -> Campaign
    mapping(uint => Contribution[]) private campaignContributions; // Campaign ID -> Contributions
    uint private campaignCounter; // To auto-increment campaign IDs

    event DIDCreated(address indexed owner, string identifier);
    event DIDUpdated(address indexed owner, string newIdentifier);
    event MetadataUpdated(address indexed owner, string name, string email, string profilePicture);
    event RoleAssigned(address indexed user, string role, address assignedBy, uint timestamp);
    event CampaignCreated(uint campaignId, string title, address owner, uint goalAmount);
    event CampaignFunded(uint campaignId, address contributor, uint amount);
    event CampaignCompleted(uint campaignId, uint totalAmountRaised);
    event CampaignStatusUpdated(uint campaignId, string newStatus);
    event ClaimSuccessful(uint campaignId, uint amountClaimed);
    event RefundIssued(uint campaignId, address contributor, uint amountRefunded);

    constructor() {
        roles[msg.sender].push("Super Admin");
        roleHistory[msg.sender].push("Super Admin");
    }

    // ---- Existing DID Functions ----
    function createDID(string memory _identifier) public {
        require(bytes(_identifier).length > 0, "Identifier cannot be empty");
        require(dids[msg.sender].owner == address(0), "DID already exists");

        dids[msg.sender] = DID({
            identifier: _identifier,
            owner: msg.sender,
            status: "active",
            verified: false
        });

        emit DIDCreated(msg.sender, _identifier);
    }

    function updateDID(string memory _newIdentifier) public {
        require(bytes(_newIdentifier).length > 0, "Identifier cannot be empty");
        require(dids[msg.sender].owner != address(0), "No DID found for this address");
        require(
            keccak256(bytes(_newIdentifier)) != keccak256(bytes(dids[msg.sender].identifier)),
            "New identifier must be different"
        );

        dids[msg.sender].identifier = _newIdentifier;

        emit DIDUpdated(msg.sender, _newIdentifier);
    }

    function getDID() public view returns (string memory, string memory, bool) {
        require(dids[msg.sender].owner != address(0), "No DID found for this address");
        DID memory userDID = dids[msg.sender];
        return (userDID.identifier, userDID.status, userDID.verified);
    }

    // ---- Metadata Functions ----
    function setMetadata(
        string memory _name,
        string memory _email,
        string memory _profilePicture,
        string memory _location,
        string memory _socialMediaLinks,
        string memory _biography
    ) public {
        require(dids[msg.sender].owner != address(0), "No DID found for this address");

        metadata[msg.sender] = Metadata({
            name: _name,
            email: _email,
            profilePicture: _profilePicture,
            location: _location,
            socialMediaLinks: _socialMediaLinks,
            biography: _biography
        });

        emit MetadataUpdated(msg.sender, _name, _email, _profilePicture);
    }

    function getMetadata()
        public
        view
        returns (
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory
        )
    {
        require(dids[msg.sender].owner != address(0), "No DID found for this address");
        Metadata memory userMetadata = metadata[msg.sender];
        return (
            userMetadata.name,
            userMetadata.email,
            userMetadata.profilePicture,
            userMetadata.location,
            userMetadata.socialMediaLinks,
            userMetadata.biography
        );
    }

    // ---- Role Management Functions ----
    function assignRole(address _user, string memory _role) public {
        require(dids[_user].owner != address(0), "User does not have a DID");
        require(keccak256(bytes(roles[msg.sender][0])) == keccak256(bytes("Super Admin")), "Only Super Admin can assign roles");

        _addRole(_user, _role);

        emit RoleAssigned(_user, _role, msg.sender, block.timestamp);
    }

    function getRole() public view returns (string[] memory) {
        require(dids[msg.sender].owner != address(0), "No DID found for this address");
        return roles[msg.sender];
    }

    function _addRole(address _user, string memory _role) internal {
        for (uint i = 0; i < roles[_user].length; i++) {
            if (keccak256(bytes(roles[_user][i])) == keccak256(bytes(_role))) {
                return; // Role already assigned
            }
        }
        roles[_user].push(_role);
        roleHistory[_user].push(_role);
    }

    // ---- Crowdfunding Functions ----
    function createCampaign(string memory _title, string memory _description, uint _goalAmount) public {
        require(dids[msg.sender].owner != address(0), "No DID found for this address");
        require(_goalAmount > 0, "Goal amount must be greater than zero");

        campaignCounter++;
        campaigns[campaignCounter] = Campaign({
            title: _title,
            description: _description,
            owner: msg.sender,
            goalAmount: _goalAmount,
            amountRaised: 0,
            isActive: true,
            createdAt: block.timestamp,
            status: "pending" 
        });

        emit CampaignCreated(campaignCounter, _title, msg.sender, _goalAmount);
    }

    function contributeToCampaign(uint _campaignId) public payable {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        // require(msg.value > 0, "Contribution must be greater than zero");

        campaigns[_campaignId].amountRaised += msg.value;
        campaignContributions[_campaignId].push(Contribution({
            contributor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            refunded: false
        }));

        emit CampaignFunded(_campaignId, msg.sender, msg.value);

        if (campaigns[_campaignId].amountRaised >= campaigns[_campaignId].goalAmount) {
            campaigns[_campaignId].isActive = false;
            campaigns[_campaignId].status = "completed"; // Campaign completed
            emit CampaignCompleted(_campaignId, campaigns[_campaignId].amountRaised);
        }
    }

    function getCampaign(uint _campaignId)
        public
        view
        returns (string memory, string memory, uint, uint, bool, address)
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.amountRaised,
            campaign.isActive,
            campaign.owner
        );
    }

    // ---- New Function to Fetch Contributors ----
    /**
     * Returns a list of contributors and their contribution amounts for a given campaign.
     * This function allows a user to view the contributors' information for a specific campaign.
     */
    function getContributors(uint _campaignId) public view returns (address[] memory, uint[] memory) {
        require(campaigns[_campaignId].isActive || campaigns[_campaignId].amountRaised > 0, "Invalid campaign ID or campaign has no contributions");

        uint contributionsCount = campaignContributions[_campaignId].length;
        address[] memory contributors = new address[](contributionsCount);
        uint[] memory amounts = new uint[](contributionsCount);

        for (uint i = 0; i < contributionsCount; i++) {
            contributors[i] = campaignContributions[_campaignId][i].contributor;
            amounts[i] = campaignContributions[_campaignId][i].amount;
        }

        return (contributors, amounts);
    }

    // ---- New Function to Update Campaign Status ----
    function updateCampaignStatus(uint _campaignId, string memory _newStatus) public {
        // Ensure that the caller has the "Super Admin" or "Admin" role
        bool isAdmin = false;
        for (uint i = 0; i < roles[msg.sender].length; i++) {
            if (keccak256(bytes(roles[msg.sender][i])) == keccak256(bytes("Super Admin")) || keccak256(bytes(roles[msg.sender][i])) == keccak256(bytes("Admin"))) {
                isAdmin = true;
                break;
            }
        }
        require(isAdmin, "Only Admin can update campaign status");
        require(campaigns[_campaignId].isActive, "Campaign is not active");

        campaigns[_campaignId].status = _newStatus;

        emit CampaignStatusUpdated(_campaignId, _newStatus);
    }

    // ---- New Claim Function ----
        /**
     * Allows the owner of a campaign to claim the funds raised if the campaign has
     * met its goal amount and is marked as "completed". The funds are transferred to the owner.
     * Emits a ClaimSuccessful event.
     */
    function claimFunds(uint _campaignId) public {
        require(campaigns[_campaignId].owner == msg.sender, "You must be the campaign owner to claim funds");
        // require(campaigns[_campaignId].amountRaised >= campaigns[_campaignId].goalAmount, "Campaign has not reached the goal amount");
        require(keccak256(bytes(campaigns[_campaignId].status)) == keccak256(bytes("completed")), "Campaign must be completed to claim funds");

        uint amountToClaim = campaigns[_campaignId].amountRaised;
        campaigns[_campaignId].amountRaised = 0; // Prevent claiming multiple times
        payable(msg.sender).transfer(amountToClaim);

        emit ClaimSuccessful(_campaignId, amountToClaim);
    }

    // ---- New Refund Function ----
        /**
     * Allows contributors to request refunds for their contributions to a campaign
     * if the campaign is not "completed". This function checks the status of the campaign,
     * and refunds the contribution amount if it has not been refunded before.
     * Emits a RefundIssued event.
     */
    function refundContribution(uint _campaignId) public {
        require(keccak256(bytes(campaigns[_campaignId].status)) != keccak256(bytes("completed")), "Refunds are not allowed for completed campaigns");
        uint refundAmount = 0;
        for (uint i = 0; i < campaignContributions[_campaignId].length; i++) {
            if (campaignContributions[_campaignId][i].contributor == msg.sender && !campaignContributions[_campaignId][i].refunded) {
                refundAmount += campaignContributions[_campaignId][i].amount;
                campaignContributions[_campaignId][i].refunded = true;
            }
        }

        require(refundAmount > 0, "No contributions to refund");
        payable(msg.sender).transfer(refundAmount);

        emit RefundIssued(_campaignId, msg.sender, refundAmount);
    }
}
