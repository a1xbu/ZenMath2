pragma ton-solidity >=0.63.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../contracts/Player.sol";

import "../abstracts/Transferable.sol";

import "../lib/Gas.sol";
import "../lib/MsgFlag.sol";


abstract contract PlayerDeployer is Transferable{
    TvmCell m_playerCode;
    uint128 m_total_players;

    function setPlayerCode(TvmCell code)
        public
        onlyOwner
    {
        tvm.accept();
        m_playerCode = code;
    }

    /*
        @notice Derive Player address from owner
        @param owner_address_ Everscale wallet address
    */
    function getExpectedPlayerAddress(
        address owner_address_
    )
        internal
        inline
        view
    returns (
        address
    ) {
        TvmCell stateInit = tvm.buildStateInit({
            contr: Player,
            code: m_playerCode,
            pubkey: 0,
            varInit: {
                root_address: address(this),
                owner_address: owner_address_
            }
        });

        return address(tvm.hash(stateInit));
    }

    function DeployPlayer() internal returns (address) {
        address player = new Player{
            value: Gas.TARGET_PLAYER_BALANCE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            code: m_playerCode,
            pubkey: 0,
            bounce: false,
            varInit: {
                root_address: address(this),
                owner_address: msg.sender
            }
        }();
        m_total_players += 1;

        return address(player);
    }

}