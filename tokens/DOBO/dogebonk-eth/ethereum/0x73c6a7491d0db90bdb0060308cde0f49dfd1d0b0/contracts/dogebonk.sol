//SPDX-License-Identifier: MIT

/**
 *                                          .yyyy-
 *                                    `yd/``+M`
 *                                  `om+-.`/ds
 *                                `+m+``./dy.
 *                               +mo```-ydmh/
 *                             /ds.``.:+++:+dh
 *                           .hh-``./+++//:/+dd/-
 *                         `sm/``-/+oooo++++//oyhm:             .`                                         ...`                          :o`
 *                       `+my/:-/sshdhys+///+++//oNo           +MMMmy/`                                   /MmdmNd+                       hM-
 *                      :No::/+++oyhyso+//+++/////oM-          oM+`-omNs`                                 +M+  `yM+            `-        hM.   ..
 *                    .yNd+oNyyyhhysooossso+///://+ym`         oM/    /NN:  `omMNms`  -ymMNMh/  -yNmmNy.  +M/  .dM:   +dNNNy.  hMhmNNh-  dM. :hMy
 *                  `sNdhmMMdhhhdhhyyyysssso+/::/+/:hh         sM/     .NN``mM/  +Ms :Md:  -Md :My..-+Nm  sMNNNMMy`  yMs` -Nd  hMs-`:MN  dM+dMs.
 *                 oNmdmm/dmhyyhhhhhhhhhhyo+//////::/N:        yM-     `NM`:My   `Md hM-   /My hMdhyso+-  sM:  `:mN-`Mm    dM  mM`   NM  mMNyMh.
 *               /mmdmd:  smsssyhhyyyyyyso+///////://ds        hM-   `:dM/ .Nm.  oMs yMs../NM+ +Mo`   :s. yM:  `-dM: dM:  :Nd  mM`   NM  NM  -mN/
 *             :mmdmd/    +msyyyyyyyysso++/////////:/M-        yMNmmNNds.   -yNNNdo  `ohddhdM:  -ymmmmh+  yMmdNNmy:  `smNNms`  hm    mm  mm   `yN-
 *           :dNdmd:      omsyyyoossssso++/:::/:://+my                                    `mN`             ```
 *         :dNmNd:   `:+shmdsyhs/:+oooyoo+/:--::::oN+                                shysyNm:
 *      .+dNmNm:    smdhsosyyyy+//+ossyso+/:--::smy.                                 `-:::.
 *     +Ndhmm+      ydddNMMdyso/osyyyyso+//-:ohd+`
 *     -mNdN/       sdddyyssyhddmmmddyso+/hdy/`
 *       `.`       `NysssyydNs`````.+Mso/dh
 *                  .dmdhdmo`       smso/dy
 *                    `..`         .Ndso/N/
 *                                 mhssohN
 *                                 /yhhy/`
 *
 *    DogeBonk token features:
 *    Bonk!
 *
 */

pragma solidity >=0.8.12 <0.9.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DogeBonk is IERC20 {
    string public constant name = "DogeBonk";
    string public constant symbol = "DOBO";
    uint256 public constant decimals = 18;
    uint256 public constant totalSupply = 420690000 * 10 ** decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        balanceOf[msg.sender] = totalSupply;
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        if (allowance[from][msg.sender] < type(uint).max) {
            allowance[from][msg.sender] -= amount;
        }
        return _transfer(from, to, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private returns (bool) {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
