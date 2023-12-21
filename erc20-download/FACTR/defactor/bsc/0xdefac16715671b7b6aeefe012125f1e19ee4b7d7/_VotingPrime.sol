// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

import "./_ChainSwap.sol";
import "./_ErrorCodes.sol";
import "./_Voting.sol";

abstract contract VotingPrime is ChainSwap, Voting {
    bool public suggestionsRestricted = false;
    bool public requireBalanceForVote = false;
    bool public requireBalanceForCreateSuggestion = false;
    bool public stakedVoting = false;
    bool public allowNoVoteComments = true;
    uint256 public voteCost;

    /**
     * @dev Configure how users can vote.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function configureVoting(
        bool restrictSuggestions,
        bool balanceForVote,
        bool balanceForCreateSuggestion,
        uint256 cost,
        bool oneVote,
        bool stakeVoting,
        uint64 duration,
        uint24 votesUsedTime,
        bool noVoteComments
    ) public onlyAdminOrAttorney {
        suggestionsRestricted = restrictSuggestions;
        requireBalanceForVote = balanceForVote;
        requireBalanceForCreateSuggestion = balanceForCreateSuggestion;
        voteCost = cost;
        oneVotePerAccount = oneVote;
        stakedVoting = stakeVoting;
        defaultDuration = duration;
        defaultVotesUsedTime = votesUsedTime;
        allowNoVoteComments = noVoteComments;
    }

    /**
     * @dev Create a new suggestion for voting.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function createSuggestion(string memory text) public {
        if (suggestionsRestricted) {
            expect(isAdmin(msg.sender) || isDelegate(msg.sender), ERROR_UNAUTHORIZED);
        } else if (requireBalanceForCreateSuggestion) {
            expect(balanceOf(msg.sender) > 0, ERROR_INSUFFICIENT_BALANCE);
        }
        _createSuggestion(text, defaultDuration, defaultVotesUsedTime);
    }

    function createSuggestionExpiring(
        string memory text,
        uint64 duration,
        uint24 votesUsedTime
    ) public {
        expect(isAdmin(msg.sender) || isDelegate(msg.sender), ERROR_UNAUTHORIZED);
        _createSuggestion(text, duration, votesUsedTime);
    }

    /**
     * @dev Vote on a suggestion.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function vote(uint256 suggestionId, string memory comment) public {
        checkVote(msg.sender, suggestionId, 1);

        _vote(msg.sender, suggestionId, 1, comment);
    }

    /**
     * @dev Cast multiple votes on a suggestion.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function multiVote(
        uint256 suggestionId,
        uint256 votes,
        string memory comment
    ) public {
        checkVote(msg.sender, suggestionId, votes);

        _vote(msg.sender, suggestionId, votes, comment);
    }

    function checkVote(
        address account,
        uint256 suggestionId,
        uint256 votes
    ) internal {
        if (requireBalanceForVote) {
            expect(balanceOf(msg.sender) > 0, ERROR_INSUFFICIENT_BALANCE);
        }
        if (oneVotePerAccount) {
            if (votes == 0) {
                expect(allowNoVoteComments, ERROR_BAD_PARAMETER_1);
            } else {
                expect(votes == 1 && !hasVoted(account, suggestionId), ERROR_ALREADY_EXISTS);
            }
        }

        if (voteCost > 0 && votes > 0) {
            _transfer(msg.sender, address(this), voteCost * votes);
        }

        if (stakedVoting) {
            if (votes > 0) {
                expect(stakeOf(msg.sender) >= votesUsedTotal(msg.sender) + votes, ERROR_TOO_HIGH);
            } else {
                expect(stakeOf(msg.sender) > 0, ERROR_UNAUTHORIZED);
            }
        }
    }
}
