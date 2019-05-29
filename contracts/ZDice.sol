pragma solidity ^0.4.25;

contract ZDice {
    address public owner = msg.sender;
    address private lastSender;
    address private lastOrigin;
    uint public totalFrozen;
    uint public stageSize = 28800; // 1 day
    uint public freezePeriod = 86400; // 3 days
    uint public tokenId = 1002459;
    uint public dividends;
    uint public prevDividends;
    uint public prevStage;
    uint public dividendsPaid;
    uint public frozenUsed;

    mapping (address => uint) public frozen;
    mapping (address => uint) public frozenAt;
    mapping (address => uint) public gotDivs;
    
    event Dice(address indexed from, uint256 bet, uint256 prize, uint256 number, uint256 rollUnder);
    
    uint private seed;
 
    modifier notContract() {
        lastSender = msg.sender;
        lastOrigin = tx.origin;
        require(lastSender == lastOrigin);
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    function getCurrentStage() public view returns (uint) {
        return block.number / stageSize;
    }
    
    // uint256 to bytes32
    function toBytes(uint256 x) internal pure returns (bytes b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), x)
        }
    }
    
    // returns a pseudo-random number
    function random(uint lessThan) internal returns (uint) {
        seed += block.timestamp + uint(msg.sender);
        return uint(sha256(toBytes(uint(blockhash(block.number - 1)) + seed))) % lessThan;
    }

    function getMaxBet() public view returns (uint) {
        uint maxBet = (address(this).balance - prevDividends - dividends + dividendsPaid) / 25;
        return maxBet > 10000000000 ? 10000000000 : maxBet;
    }

    function getProfit(uint amount) external onlyOwner {
        uint max = address(this).balance - prevDividends - dividends + dividendsPaid;
        owner.transfer(amount < max ? amount : max);
    }
    
    function dice(uint rollUnder) external payable notContract {
        require(msg.value >= 5000000 && msg.value <= getMaxBet());
        require(rollUnder >= 4 && rollUnder <= 95);

        uint stage = getCurrentStage();
        if (stage > prevStage) {
            prevDividends = dividends;
            dividends = 0;

            prevStage = stage;

            dividendsPaid = 0;
            frozenUsed = 0;
        }

        msg.sender.transferToken(1000000, tokenId);
        
        uint number = random(100);
        if (number < rollUnder) {
            uint prize = msg.value * 98 / rollUnder;
            msg.sender.transfer(prize);
            uint divToSub = (prize - msg.value) / 2;
            dividends = divToSub < dividends ? dividends - divToSub : 0;
            emit Dice(msg.sender, msg.value, prize, number, rollUnder);
        } else {
            dividends += msg.value / 2;
            emit Dice(msg.sender, msg.value, 0, number, rollUnder);
        }
    }

    function freeze() external payable {
        require(msg.tokenid == tokenId);
        require(msg.tokenvalue > 0);
        frozen[msg.sender] += msg.tokenvalue;
        frozenAt[msg.sender] = block.number;
        totalFrozen += msg.tokenvalue;
    }

    function unfreeze() external {
        require(block.number - frozenAt[msg.sender] >= freezePeriod);
        totalFrozen -= frozen[msg.sender];
        msg.sender.transferToken(frozen[msg.sender], tokenId);
        frozen[msg.sender] = 0;
        delete frozenAt[msg.sender];
    }

    function getDivs() external {
        require(prevDividends > dividendsPaid);
        require(totalFrozen > frozenUsed);
        uint stage = getCurrentStage();
        require(stage > gotDivs[msg.sender]);
        gotDivs[msg.sender] = stage;
        uint amount = (prevDividends - dividendsPaid) * frozen[msg.sender] / (totalFrozen - frozenUsed);
        require(amount > 0);
        msg.sender.transfer(amount);
        dividendsPaid += amount;
        frozenUsed += frozen[msg.sender];
    }

    function () external payable onlyOwner {

    }
}