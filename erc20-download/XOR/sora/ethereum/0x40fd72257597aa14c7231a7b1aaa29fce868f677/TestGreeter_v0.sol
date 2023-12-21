pragma solidity ^0.5.8;

contract TestGreeter_v0 {
    bool ininialized_;

    string greeting_;

    constructor(string memory greeting) public {
        initialize(greeting);
    }

    function initialize(string memory greeting) public {
        require(!ininialized_);
        greeting_ = greeting;
        ininialized_ = true;
    }

    function greet() view public returns (string memory) {
        return greeting_;
    }

    function set(string memory greeting) public {
        greeting_ = greeting;
    }
}
