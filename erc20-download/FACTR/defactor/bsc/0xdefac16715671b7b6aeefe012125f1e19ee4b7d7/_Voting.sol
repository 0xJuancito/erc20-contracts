// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

/**
 * @dev Suggestions and Voting for token-holders.
 *
 * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
 */
contract Voting {
    struct Suggestion {
        uint256 id;
        uint256 votes;
        bool created;
        address creator;
        uint64 expiration;
        uint24 votesUsedTime;
        string text;
    }

    struct UsedVotes {
        uint256 value;
        uint64 expiration;
    }

    // This stores how many votes a user has cast on a suggestion
    mapping(uint256 => mapping(address => uint256)) private voted;

    // Tracks when used votes get freed up again
    mapping(address => UsedVotes[]) private usedVotes;

    // This map stores the suggestions, and they're retrieved using their ID number
    Suggestion[] internal suggestions;

    // If true, a wallet can only vote on a suggestion once
    bool public oneVotePerAccount = true;

    uint64 public defaultDuration;
    uint24 public defaultVotesUsedTime;

    event SuggestionCreated(uint256 suggestionId, string text);
    event Votes(
        address voter,
        uint256 indexed suggestionId,
        uint256 votes,
        uint256 totalVotes,
        string comment
    );

    /**
     * @dev Gets the number of votes a suggestion has received.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function getVotes(uint256 suggestionId) public view returns (uint256) {
        return suggestions[suggestionId].votes;
    }

    /**
     * @dev Gets the text of a suggestion.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function getSuggestionText(uint256 suggestionId) public view returns (string memory) {
        return suggestions[suggestionId].text;
    }

    /**
     * @dev Gets whether or not an account has voted for a suggestion.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function hasVoted(address account, uint256 suggestionId) public view returns (bool) {
        return voted[suggestionId][account] > 0;
    }

    /**
     * @dev Gets the number of votes an account has cast towards a suggestion.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function getAccountVotes(address account, uint256 suggestionId) public view returns (uint256) {
        return voted[suggestionId][account];
    }

    /**
     * @dev Gets the creator of a suggestion.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function getSuggestionCreator(uint256 suggestionId) public view returns (address) {
        return suggestions[suggestionId].creator;
    }

    function getAllSuggestions() public view returns (Suggestion[] memory) {
        return suggestions;
    }

    function getAllActiveSuggestions() public view returns (Suggestion[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < suggestions.length; i++) {
            if (suggestions[i].expiration > block.timestamp) {
                ++activeCount;
            }
        }
        Suggestion[] memory list = new Suggestion[](activeCount);

        if (activeCount > 0) {
            uint256 pos = 0;
            for (uint256 i = 0; i < suggestions.length; i++) {
                if (suggestions[i].expiration > block.timestamp) {
                    list[pos++] = suggestions[i];
                }
            }
        }

        return list;
    }

    /**
     * @dev Gets the total amount of votes unavailable due to being used.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function votesUsedTotal(address account) public view returns (uint256) {
        UsedVotes[] storage list = usedVotes[account];
        uint256 total = 0;
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i].expiration > block.timestamp) {
                total += list[i].value;
            }
        }

        return total;
    }

    /**
     * @dev Lists all the locks for the given account as an array, with [value1, expiration1, value2, expiration2, ...]
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function votesUsed(address account) public view returns (UsedVotes[] memory) {
        return usedVotes[account];
    }

    /**
     * @dev Internal logic for creating a suggestion.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function _createSuggestion(
        string memory text,
        uint64 duration,
        uint24 votesUsedTime
    ) internal {
        // The ID is just based on the suggestion count, so the IDs go 0, 1, 2, etc.
        uint256 suggestionId = suggestions.length;

        uint64 expires = 0;
        if (duration > 0) {
            expires = uint64(block.timestamp) + duration;
        }
        // Starts at 0 votes
        suggestions.push(Suggestion(suggestionId, 0, true, msg.sender, expires, votesUsedTime, text));

        emit SuggestionCreated(suggestionId, text);
    }

    /**
     * @dev Internal logic for voting.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function _vote(
        address account,
        uint256 suggestionId,
        uint256 votes,
        string memory comment
    ) internal returns (uint256) {
        _cleanUsedVotes(account);

        Suggestion storage sugg = suggestions[suggestionId];

        require(sugg.expiration == 0 || sugg.expiration > block.timestamp);

        if (sugg.votesUsedTime > 0) {
            usedVotes[account].push(UsedVotes(votes, uint64(block.timestamp) + sugg.votesUsedTime));
        }

        voted[suggestionId][account] += votes;
        sugg.votes += votes;

        emit Votes(account, suggestionId, votes, sugg.votes, comment);

        return sugg.votes;
    }

    function _cleanUsedVotes(address account) internal returns (bool) {
        UsedVotes[] storage list = usedVotes[account];
        if (list.length == 0) {
            return true;
        }

        for (uint256 i = 0; i < list.length; ) {
            UsedVotes storage used = list[i];
            if (used.expiration < block.timestamp) {
                if (i < list.length - 1) {
                    list[i] = list[list.length - 1];
                }
                list.pop();
            } else {
                i++;
            }
        }

        return true;
    }
}
