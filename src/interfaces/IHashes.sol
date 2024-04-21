// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {IERC721Enumerable} from "openzeppelin/token/ERC721/extensions/IERC721Enumerable.sol";

interface IHashes is IERC721Enumerable {
    function deactivated(uint256 _tokenId) external view returns (bool);

    function governanceCap() external view returns (uint256);
}
