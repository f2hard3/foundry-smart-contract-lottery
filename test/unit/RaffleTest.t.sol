// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffleScript} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle private raffle;
    HelperConfig private helperConfig;

    uint256 private entranceFee;
    uint256 private interval;
    address private vrfCoordinator;
    bytes32 private gasLane;
    uint32 private callbackGasLimit;
    uint256 private subscriptionId;

    address private player = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffleScript deployer = new DeployRaffleScript();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(player, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() external view {
        // Arrange
        Raffle.RaffleState expectedState = Raffle.RaffleState.OPEN;

        // Act
        Raffle.RaffleState actualState = raffle.getRaffleState();

        // Assert
        assertEq(
            uint256(actualState),
            uint256(expectedState),
            "Raffle should start in OPEN state"
        );
    }

    /**
     * Enter raffle
     */
    function testRaffleRevertsWhenYouDontPayEnough() external {
        // Arrange
        vm.startPrank(player);
        uint256 insufficientAmount = entranceFee - 0.001 ether;

        // Act and Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: insufficientAmount}();
        vm.stopPrank();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() external {
        // Arrange
        vm.startPrank(player);

        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        address payable[] memory players = raffle.getPlayers();
        assertEq(players.length, 1, "There should be one player in the raffle");
        assertEq(players[0], player, "The player should be recorded correctly");

        vm.stopPrank();
    }

    function testEnteringRaffleEmitsEvent() external {
        // Arrange
        vm.startPrank(player);

        // Act and Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersEnterWhileRaffleIsCalculating() external {
        // Arrange
        vm.startPrank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        // Move time forward to trigger upkeep
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        raffle.performUpkeep("");

        // Assert
        vm.startPrank(player);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * checkUpkeep
     */
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() external {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded, "Upkeep should not be needed if no balance");
    }

    function testCheckUpkeepReturnsFalseIfItIsNotOpened() external {
        // Arrange
        vm.startPrank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        // Move time forward to trigger upkeep
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(
            upkeepNeeded,
            "Upkeep should not be needed if raffle is not open"
        );
    }

    /**
     * performUpkeep
     */
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() external {
        // Arrange
        vm.startPrank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        // Move time forward to trigger upkeep
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        raffle.performUpkeep("");

        // Assert
        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.CALCULATING),
            "Raffle state should be CALCULATING"
        );
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() external {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act and Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector,
                address(raffle).balance,
                0, // No players
                uint256(Raffle.RaffleState.OPEN)
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        // Arrange
        vm.startPrank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
        // Move time forward to trigger upkeep
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        external
        raffleEntered
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");

        // Assert
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assertEq(
            uint256(raffleState),
            uint256(Raffle.RaffleState.CALCULATING),
            "Raffle state should be CALCULATING"
        );
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    /**
     * fulfillRandomWords
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) external raffleEntered skipFork {
        // Act and Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        external
        raffleEntered
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 3; // 4 total players
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < additionalEntrants + startingIndex;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == uint256(Raffle.RaffleState.OPEN));
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
