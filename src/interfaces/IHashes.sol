// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";

interface IHashes is IERC721 {
    /// @notice Gets the deactivated status of the Hashes NFT.
    /// @param _tokenId The token ID of the Hashes NFT.
    /// @return The deactivated status. True if the NFT is deactivated.
    function deactivated(uint256 _tokenId) external view returns (bool);
}
