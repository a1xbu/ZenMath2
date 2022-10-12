pragma ton-solidity >=0.63.0;

import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Terminal/Terminal.sol";


abstract contract DebugOutput {
    bool debug = false;
    function DbgPrint(string data) internal inline view { if(debug) Terminal.print(0, data); }
}