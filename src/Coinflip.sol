// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import {VRFv2DirectFundingConsumer} from "src/VRFv2DirectFundingConsumer.sol";
import {LinkTokenInterface} from "node_modules/@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

contract Coinflip is Ownable {
    struct Request {
        bool fulfilled;
        uint256[] randomWords;
    }
    mapping(uint256 => Request) public s_requests;
    // A map of the player and their corresponding random number request
    mapping(address => uint256) public playerRequestID;
    // A map that stores the users coinflip guess
    mapping(address => uint8) public bets;
    // An instance of the random number requestor, client interface
    VRFv2DirectFundingConsumer private vrfRequestor;

    ///@notice This programming pattern is a factory model - a contract creating other contracts 
    constructor(address _vrfRequestor)Ownable(msg.sender) {
        vrfRequestor = VRFv2DirectFundingConsumer(_vrfRequestor);
    }

    ///@notice Fund the VRF instance with **2** LINK tokens.
    ///@return A boolean of whether funding the VRF instance with link tokens was successful or not
    function fundOracle() external onlyOwner returns(bool) {
        address linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        // Transfer 2 LINK tokens to the VRF contract
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        uint256 amount = 2 * 10**18; // 2 LINK tokens in 18 decimals
        require(link.transfer(address(vrfRequestor), amount), "Unable to transfer LINK");
        return true;
    }

    ///@notice User guess only ONE flip either a 1 or a 0.
    ///@param guess uint8 which is required to be 1 or 0
    ///@dev After validating the user input, store the user input in global mapping and fire off a request to the VRF instance
    ///@dev Then, store the requestid in global mapping
    function userInput(uint8 guess) external {
        require(guess == 0 || guess == 1, "Invalid guess");
        bets[msg.sender] = guess;
        // Request a random number from the VRF oracle
        uint256 requestId = vrfRequestor.requestRandomWords();
        playerRequestID[msg.sender] = requestId;
    }

    ///@notice due to the fact that a blockchain does not deliver data instantaneously, in fact quite slowly under congestion, allow
    ///        users to check the status of their request.
    ///@return a boolean of whether the request has been fulfilled or not
    function checkStatus() external view returns(bool) {
        uint256 requestId = playerRequestID[msg.sender];
        (uint256 requestIdFromMapping, bool fulfilled) = vrfRequestor.s_requests(requestId);
        require(requestId == requestIdFromMapping, "Invalid request ID"); // Ensure the request ID matches
        return fulfilled;
    }

    ///@notice once the request is fulfilled, return the random result and check if user won
    ///@return a boolean of whether the user won or not based on their input
    function determineFlip() external view returns(bool) {
        uint256 requestId = playerRequestID[msg.sender];
        (uint256 requestIdFromMapping, bool fulfilled) = vrfRequestor.s_requests(requestId);
        require(requestId == requestIdFromMapping, "Invalid request ID"); // Ensure the request ID matches
        require(fulfilled, "Request not fulfilled yet");
    
        uint256[] memory randomWords = s_requests[requestId].randomWords; // Access randomWords directly from s_requests mapping
        require(randomWords.length > 0, "Random number not received yet");
    
        // Determine the outcome of the coin flip based on the random number
        uint256 result = randomWords[0] % 2;
        return (result == bets[msg.sender]);
    }
}