pragma ton-solidity >=0.39.0;

interface IUserWallet {
    function submitTransaction(
        address dest,
        uint128 value,
        bool bounce,
        bool allBalance,
        TvmCell payload
    ) external returns (uint64 transId);
}
