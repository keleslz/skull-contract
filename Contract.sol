// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

contract Training {

    uint private startPrice = 20000000000000000; // 0.02ETH
    uint private priceLevel = 0;
    uint public totalSupply = 1_111;

    address private owner;
    uint public actualPrice;
    uint public skullRemainsForSale; // update after each sale
    uint private nextSkullIndexToSale; // update after each sale

    struct Skull {
        uint index;
        address owner;
        string rarity;
        uint price;
        bool exist;
    }

    struct Bid {
        Skull skull;
        address bidder;
        uint price;
        bool exist;
        bool isDone;
        bool isAccepted;
    }

    /*
    *   Save counts of current acquisition of each buyer after each buy
    *
    *  _owner => _acquisitionCount
    */
    mapping(address => uint) acquisitionCount;

    /**
    *   Save a bid for one Skull by index, used to store each bid
    *
    *  _skullIndex => Bid
    */
    mapping(uint => Bid) public bids;

    /**
    *   Retrieve a skull by _skullIndex
    *
    *   _skullIndex => Skull
    */
    mapping(uint => Skull) public skulls;

    /**
    *   Retrieve a skull by _skullIndex
    *
    *   _skullIndex => bool
    */
    mapping(uint => bool) areOpenToBid;

    /**
    *    Records the amount of a bid to return it to the seller
    *
    *   _skullIndex => _amount
    */
    mapping(uint => uint) withdrawBidsPending;


    /**
    *   When buy skull
    */
    event BuySkull(Skull skull);

    /**
    *   When place bid
    */
    event PlaceBid(Bid bid);

    /**
    *   Do transfer from _lastOwner to _newOwner
    */
    event Transfer(address _lastOwner, address _newOwner);

    constructor() {
        owner = msg.sender;
        skullRemainsForSale = totalSupply;
        actualPrice = startPrice;
    }

    /*
    *   Just to buy Skull. Not for auction or others,
    *   when 1110 skulls are solds, function will be not usable
    */
    function buySkull() public payable {
        require(msg.sender != owner, "Action unauthorized");
        require(msg.value > 0, "Value sended too low");
        require(msg.sender != owner, "Seller can't be owner");
        require(skullRemainsForSale > 1, "Skull remains for sale must be > 1");
        require(msg.sender.balance >= msg.value, "Not enough money to buy this item");

        acquisitionCount[msg.sender]++;

        Skull memory _skull = Skull(nextSkullIndexToSale, msg.sender, getRarity(), msg.value, true);
        skulls[nextSkullIndexToSale] = _skull;

        updateSkullPrice();

        nextSkullIndexToSale++;
        skullRemainsForSale--;

        emit BuySkull(_skull);
    }

    /**
    *   Open or close aution
    */
    function setAuctionState(uint _skullIndex, bool _isOpen) external {
        require(msg.sender == owner, "Action unauthorized");
        areOpenToBid[_skullIndex] = _isOpen;
    }

    /**
    *   To place a bid, but all Skulls must be sold.
    *   Minimal price is based on _lastBid price if exist otherwise
    *   on Skull purchase price
    */
    function placeBid(uint _skullIndex, uint _price, address _bidder) external payable {
        require(areOpenToBid[_skullIndex] == true, "Auction not open");
        require(msg.sender != owner, "Action unauthorized");
        require(msg.sender != skulls[_skullIndex].owner, "Skull owner cannot place bid on his item");
        require(_bidder != address(0), "Address not valid");
        require(_skullIndex < totalSupply, "Index out of range");
        require(skullRemainsForSale == 0, "All skulls must be selled to do bid");

        _createBid(_skullIndex, _price, _bidder);
    }

    /**
    *    Only authorized by skulls Golds owner
    */
    function placeXRarBid(uint _price, address _bidder) external payable {
        require(skullRemainsForSale == 1, "Only one skull should remain");

        bool _isGoldOwner;

        for (uint i = totalSupply - 1; i >= (totalSupply - 11); i--)
        {
            if (skulls[i].owner == msg.sender)
            {
                _isGoldOwner = true;
                break;
            }
        }

        require(_isGoldOwner == true, "Authorized only for Golds Skull owner");

        _createBid(totalSupply - 1, _price, _bidder);
    }

    /**
    *   To Create a bid
    */
    function _createBid(uint _skullIndex, uint _price, address _bidder) internal {
        payable(address(this)).transfer(_price);
        withdrawBidsPending[_skullIndex] = _price;

        Bid memory _lastBid = bids[_skullIndex];

        if (_lastBid.exist == true)
        {
            require(_price > _lastBid.price, "New price lower than old price");
            require(_lastBid.skull.owner != _bidder, "Cannot place bid for owner of item");

            Bid memory _newBid = Bid(_lastBid.skull, _bidder, _price, true, false, false);
            bids[_skullIndex] = _newBid;
            emit PlaceBid(_newBid);
        } else {
            require(skulls[_skullIndex].owner != _bidder, "Cannot place bid for owner of item");
            require(_price > _lastBid.skull.price, "Bid price lower than purchase price");

            Bid memory _newBid = Bid(skulls[_skullIndex], _bidder, _price, true, false, false);
            bids[_skullIndex] = _newBid;
            emit PlaceBid(_newBid);
        }


    }

    /**
    *   Reply to a bid placed
    */
    function replyBidForSkull(uint _skullIndex, bool _isAccept) external {
        require(areOpenToBid[_skullIndex] == true, "Auction not open");

        require(_skullIndex < totalSupply, "Index out of range");
        require(skullRemainsForSale == 0, "All skulls must be selled to accept bid");
        require(skulls[_skullIndex].owner == msg.sender, "Must be valid by skull owner");

        address _lastOwner = skulls[_skullIndex].owner;

        if (_isAccept == true)
        {
            Bid memory _bid = bids[_skullIndex];
            address _bidder = _bid.bidder;

            skulls[_skullIndex].owner = _bidder;
            bids[_skullIndex].isAccepted = true;

            acquisitionCount[_lastOwner]--;
            acquisitionCount[_bidder]++;

            payable(msg.sender).transfer(_bid.price);

            emit Transfer(msg.sender, _bidder);
        } else {

            Bid memory _bid = bids[_skullIndex];
            address _bidder = _bid.bidder;

            bids[_skullIndex].isAccepted = false;

            payable(_bidder).transfer(_bid.price);
        }

        withdrawBidsPending[_skullIndex] = 0;
        bids[_skullIndex].isDone = true;
        areOpenToBid[_skullIndex] = false;
    }

    // /**
    // *   Must be called by seller and not by bidder.
    // *   Accept bid for
    // */
    // function acceptBidForSkull(uint _skullIndex, uint minPrice) external {
    //     require(_skullIndex < totalSupply, "Index out of range");
    //     require(skullRemainsForSale != 0, "All skulls must selled to do bid");
    //     require(bids[_skullIndex].skull.owner == msg.sender);
    //     address _seller = msg.sender;

    //     Bid bid = bids[_skullIndex];

    //     require(bid.value == 0);
    //     require(bid.value < minPrice);

    //     punkIndexToAddress[_skullIndex] = bid.bidder;
    //     acquisitionCount[_seller]--;
    //     acquisitionCount[bid.bidder]++;
    //     Transfer(_seller, bid.bidder, 1);

    //     punksOfferedForSale[_skullIndex] = Offer(false, _skullIndex, bid.bidder, 0, 0x0);
    //     uint amount = bid.value;
    //     punkBids[_skullIndex] = Bid(false, _skullIndex, 0x0, 0);
    //     pendingWithdrawals[_seller] += amount;
    //     PunkBought(_skullIndex, bid.value, _seller, bid.bidder);
    // }

    function getRarity() public view returns (string memory) {
        if (skullRemainsForSale == 1) {// remain 1 gold
            return "xRar";
        } else if (skullRemainsForSale <= 11) {// remains 10 Golds + 1 xRar
            return "Gold";
        } else {
            return "Common";
        }
    }

    /*
    *  update Skull price after level sale
    *
    */
    function updateSkullPrice() public {// Will be private
        bool _isUnlockLevel = getIsUnlockLevel();
        uint _soldLevel = getCurrentSkullSoldLevel();

        if (_soldLevel == 1 && _isUnlockLevel) {
            actualPrice += 10000000000000000;
        } else if (_soldLevel == 2 && _isUnlockLevel) {
            actualPrice += 20000000000000000;
        } else if (_soldLevel == 3 && _isUnlockLevel) {
            actualPrice += 30000000000000000;
        }
    }

    /*
    *  50 > {vaue} <= 100 level0
    *  35 => {vaue} <= 50 + level1
    *  15 => {vaue} < 35 + level2
    *  0 =>  {vaue}< 15 + level3
    */
    function getCurrentSkullSoldLevel() public view returns (uint) {
        uint fiftyPercent = 556;
        uint thirtyFivePercent = 389;
        uint fifteenPercent = 167;

        if (skullRemainsForSale > fiftyPercent && skullRemainsForSale <= totalSupply) {
            return 0;
        } else if (skullRemainsForSale >= thirtyFivePercent && skullRemainsForSale <= fiftyPercent) {
            return 1;
            // >=389 and <=556
        } else if (skullRemainsForSale >= fifteenPercent && skullRemainsForSale <= thirtyFivePercent) {
            return 2;
            // >=167 and <=389
        } else if (skullRemainsForSale >= 0 && skullRemainsForSale <= fifteenPercent) {
            return 3;
            // >=0 and <=167
        }

        // >=556 and <= 1111
        return 0;
    }

    function getIsUnlockLevel() public view returns (bool){

        uint fiftyPercent = 556;
        uint thirtyFivePercent = 389;
        uint fifteenPercent = 167;

        uint[3] memory _levels = [uint(fiftyPercent), uint(thirtyFivePercent), uint(fifteenPercent)];

        for (uint i = 0; i < _levels.length; i++)
        {
            if (_levels[i] == skullRemainsForSale)
            {
                return true;
            }
        }

        return false;
    }

    //Function to delete
    function setSkullRemainsForSale(uint _value) public {
        skulls[totalSupply - 2] = Skull(totalSupply - 2, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, "Gold", uint(90000000000000000), true);
        skulls[totalSupply - 3] = Skull(totalSupply - 3, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, "Gold", uint(100000000000000000), true);
        skullRemainsForSale = _value;
    }

    // Get actual money on contract
    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function withdraw() public payable {
        require(msg.sender == owner, "Action unauthorized");
        require(address(this).balance > 0, "Nothing to withdraw");
        payable(msg.sender).transfer(address(this).balance);
    }
}
