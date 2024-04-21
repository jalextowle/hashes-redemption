// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IHashes} from "./IHashes.sol";

interface IHashesDAO {
    function hashesToken() external view returns (IHashes);
}
