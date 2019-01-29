pragma solidity >=0.5.0 <0.6.0;

interface IXyIntersectionRequest {
    function completionBool(uint question, bool answer) external;
    // function completionString(uint question, string memory answer) external;
}