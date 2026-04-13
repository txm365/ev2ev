// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// EV2EV EnergyEscrow Contract
//
// Flow:
//   1. Buyer calls deposit() with ETH/POL — funds locked in contract
//   2. Seller delivers energy, calls confirmDelivery()
//   3. Buyer confirms receipt, calls confirmReceipt()
//      → contract releases funds to seller (minus platform fee)
//
// Alternate paths:
//   • Buyer calls raiseDispute() within 24h of delivery
//     → owner calls resolveDispute(tradeId, winner) to settle
//   • 48h timeout with no action → buyer calls refund()
//
// ─────────────────────────────────────────────────────────────────────────────

contract EnergyEscrow {

    // ── Status enum — matches EscrowStatus in blockchain_provider.dart ────────
    enum Status { Pending, Delivered, Completed, Disputed, Refunded }

    // ── Trade struct ──────────────────────────────────────────────────────────
    struct Trade {
        address payable buyer;
        address payable seller;
        uint256 amount;          // wei locked in escrow
        uint256 energyKwh;       // scaled ×1000 (e.g. 1500 = 1.5 kWh)
        uint256 pricePerKwh;     // scaled ×1000 (wei per kWh)
        uint256 createdAt;       // block.timestamp
        uint256 confirmedAt;     // timestamp when delivery confirmed
        Status  status;
        string  supabaseTradeId; // energy_requests.id from Supabase
    }

    // ── State ─────────────────────────────────────────────────────────────────
    address public owner;
    uint256 public platformFeeBps = 150; // 1.5% (basis points)

    uint256 public constant DISPUTE_WINDOW  = 24 hours;
    uint256 public constant TIMEOUT_WINDOW  = 48 hours;

    mapping(bytes32 => Trade) public trades;

    // ── Events ────────────────────────────────────────────────────────────────
    event Deposited(bytes32 indexed tradeId, address buyer, address seller, uint256 amount, string supabaseTradeId);
    event DeliveryConfirmed(bytes32 indexed tradeId);
    event ReceiptConfirmed(bytes32 indexed tradeId, uint256 sellerPayout, uint256 fee);
    event DisputeRaised(bytes32 indexed tradeId);
    event DisputeResolved(bytes32 indexed tradeId, address winner);
    event Refunded(bytes32 indexed tradeId);

    // ── Modifiers ─────────────────────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier tradeExists(bytes32 tradeId) {
        require(trades[tradeId].buyer != address(0), "Trade not found");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BUYER — Step 1: lock funds
    // ─────────────────────────────────────────────────────────────────────────
    function deposit(
        address payable seller,
        uint256 energyKwh,
        uint256 pricePerKwh,
        string calldata supabaseTradeId
    ) external payable returns (bytes32 tradeId) {
        require(msg.value > 0,          "Must send funds");
        require(seller != address(0),   "Invalid seller");
        require(seller != msg.sender,   "Buyer and seller must differ");
        require(energyKwh > 0,          "Energy must be positive");

        tradeId = keccak256(abi.encodePacked(
            msg.sender, seller, block.timestamp, supabaseTradeId
        ));

        require(trades[tradeId].buyer == address(0), "Trade ID collision");

        trades[tradeId] = Trade({
            buyer:          payable(msg.sender),
            seller:         seller,
            amount:         msg.value,
            energyKwh:      energyKwh,
            pricePerKwh:    pricePerKwh,
            createdAt:      block.timestamp,
            confirmedAt:    0,
            status:         Status.Pending,
            supabaseTradeId: supabaseTradeId
        });

        emit Deposited(tradeId, msg.sender, seller, msg.value, supabaseTradeId);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SELLER — Step 2: confirm energy delivered
    // ─────────────────────────────────────────────────────────────────────────
    function confirmDelivery(bytes32 tradeId)
        external
        tradeExists(tradeId)
    {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.seller,       "Only seller");
        require(t.status == Status.Pending,   "Trade not pending");

        t.status      = Status.Delivered;
        t.confirmedAt = block.timestamp;

        emit DeliveryConfirmed(tradeId);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BUYER — Step 3: confirm receipt → releases funds
    // ─────────────────────────────────────────────────────────────────────────
    function confirmReceipt(bytes32 tradeId)
        external
        tradeExists(tradeId)
    {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.buyer,           "Only buyer");
        require(t.status == Status.Delivered,    "Not yet delivered");

        t.status = Status.Completed;

        uint256 fee    = (t.amount * platformFeeBps) / 10000;
        uint256 payout = t.amount - fee;

        t.seller.transfer(payout);
        payable(owner).transfer(fee);

        emit ReceiptConfirmed(tradeId, payout, fee);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BUYER — raise dispute within 24h of delivery confirmation
    // ─────────────────────────────────────────────────────────────────────────
    function raiseDispute(bytes32 tradeId)
        external
        tradeExists(tradeId)
    {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.buyer,         "Only buyer");
        require(t.status == Status.Delivered,  "Must be delivered");
        require(
            block.timestamp <= t.confirmedAt + DISPUTE_WINDOW,
            "Dispute window closed"
        );

        t.status = Status.Disputed;
        emit DisputeRaised(tradeId);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OWNER — resolve dispute by choosing winner
    // ─────────────────────────────────────────────────────────────────────────
    function resolveDispute(bytes32 tradeId, address payable winner)
        external
        onlyOwner
        tradeExists(tradeId)
    {
        Trade storage t = trades[tradeId];
        require(t.status == Status.Disputed, "Not disputed");
        require(
            winner == t.buyer || winner == t.seller,
            "Winner must be buyer or seller"
        );

        t.status = Status.Completed;
        winner.transfer(t.amount);

        emit DisputeResolved(tradeId, winner);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BUYER — claim refund if timeout elapsed with no delivery
    // ─────────────────────────────────────────────────────────────────────────
    function refund(bytes32 tradeId)
        external
        tradeExists(tradeId)
    {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.buyer,       "Only buyer");
        require(t.status == Status.Pending,  "Must be pending");
        require(
            block.timestamp >= t.createdAt + TIMEOUT_WINDOW,
            "Timeout not yet elapsed"
        );

        t.status = Status.Refunded;
        t.buyer.transfer(t.amount);

        emit Refunded(tradeId);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // VIEW — read trade status (uint8 matching EscrowStatus enum)
    // ─────────────────────────────────────────────────────────────────────────
    function getTradeStatus(bytes32 tradeId)
        external
        view
        tradeExists(tradeId)
        returns (uint8)
    {
        return uint8(trades[tradeId].status);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // VIEW — read full trade struct
    // ─────────────────────────────────────────────────────────────────────────
    function getTrade(bytes32 tradeId)
        external
        view
        tradeExists(tradeId)
        returns (Trade memory)
    {
        return trades[tradeId];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OWNER — update platform fee (max 5%)
    // ─────────────────────────────────────────────────────────────────────────
    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 500, "Fee cannot exceed 5%");
        platformFeeBps = newFeeBps;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OWNER — transfer ownership
    // ─────────────────────────────────────────────────────────────────────────
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}
