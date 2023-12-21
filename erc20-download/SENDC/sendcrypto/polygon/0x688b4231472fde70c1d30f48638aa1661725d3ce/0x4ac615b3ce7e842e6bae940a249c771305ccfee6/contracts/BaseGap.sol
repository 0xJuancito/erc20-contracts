// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

/**
 * @author Maxim Vasilkov <maxim@vasilkoff.com>
 * @title  BaseGap
 * @notice owner: https://sendcrypto.com/      
 * @dev reserves a gap for the updates  
 *
 *    ____                          ___          ____                                                 
 *   6MMMMb\                        `MM         6MMMMb/                                               
 *  6M'    `                         MM        8P    YM                                /              
 *  MM         ____  ___  __     ____MM       6M      Y ___  __ ____    ___ __ ____   /M      _____   
 *  YM.       6MMMMb `MM 6MMb   6MMMMMM       MM        `MM 6MM `MM(    )M' `M6MMMMb /MMMMM  6MMMMMb  
 *   YMMMMb  6M'  `Mb MMM9 `Mb 6M'  `MM       MM         MM69 "  `Mb    d'   MM'  `Mb MM    6M'   `Mb 
 *       `Mb MM    MM MM'   MM MM    MM       MM         MM'      YM.  ,P    MM    MM MM    MM     MM 
 *        MM MMMMMMMM MM    MM MM    MM       MM         MM        MM  M     MM    MM MM    MM     MM 
 *        MM MM       MM    MM MM    MM       YM      6  MM        `Mbd'     MM    MM MM    MM     MM 
 *  L    ,M9 YM    d9 MM    MM YM.  ,MM        8b    d9  MM         YMP      MM.  ,M9 YM.  ,YM.   ,M9 
 *  MYMMMM9   YMMMM9 _MM_  _MM_ YMMMMMM_        YMMMM9  _MM_         M       MMYMMM9   YMMM9 YMMMMM9  
 *                                                                 d'        MM                       
 *                                                            (8),P          MM                       
 *                                                             YMM          _MM_                      
 *
 */

contract BaseGap {
    uint256[50] __gap;
}