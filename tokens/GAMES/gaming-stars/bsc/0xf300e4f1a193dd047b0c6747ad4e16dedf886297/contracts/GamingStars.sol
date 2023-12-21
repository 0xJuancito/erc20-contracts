//SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import './BEP20Token.sol';

//                                                     `',''..``.',,~~;!;;;,,'`
//                                              `~;;;~;^*T}S6R&Q@@@@@@@@@@@@@@@@@@QQDwJ=~`
//                                          ~r^^^<T}EDBQQQQQQQWD6w5YJTTL*=?|?i7sywqgQ@@@@@@Qqt;`
//                                     .=***?JyURW#&BgqS}T<!;;;;;~~~__,,,'''..```      `';LyDQQQQWo=.
//                                  ~L|?iJykbDR%qm}\=^r+r^^^!!~==,;},.=j5Y~    ;<!             ~?SW8WR5^`
//                               ;TT\7}SUqqqXyz?=<<<<=^!!5X;wb~6Q6=QLiQ~*yo`  ,QTi; ;UK*`  `        ~tbDbUi'
//                            ~777JfSEXUwyJi?**??\==JQR\=QQYLQLYQ=qQm;bw}Ry.` ;J*Q<  W=  ,b%S  ,,       ~7wayL.
//                          LJJt}ySwESf7i????|??gQRJ=bBbRB}B=XY=5!~*^,,~;,...`.;*!  ~U  }&oES ;Q;}a        `*s7\;
//                       .zttY}yoaajt7???iybbX7|DRbQ6Yg7ts;;_,,,,,,,,,,,,,''''.....````.,  ?y`&yQJ, bta~      .+|*r`
//                     .ttts}jyyy}ti*?T77fQoyKQoXQYiz^~~~~~!^^!!!;;;;;~~~,,,''..```     ``````` X``!;m,          ,^!;`
//                   .7tttY}fj}s7**\tJz77zK#KRRJ?;~~;=?**<==+r^^!!!;;;;;~~~,,,''..```         ```  <iy'             ~~~.
//                  7JJJts}}}s7=*zttttJJz777s=~;;?iiL????***==+r^^!!!;;;;~~~~_,,''..```           ```                 ,,'`
//                +JJJzJtYYt7=*tttttttSXJJ*;;rT77T\\iiL?|??***==+r^^!^^r^^!!;~~,,,''..```            ```  .i            ..`
//               77777zJtt7^=JX%Ettttt}z;;=zz777777T\\iiL|?LzfSkkXXXXXkwwEEkXUXkways|!,.````             ``       ~!.     ``
//             !777777JJz+^7JmQbDgg}ti~;7ttJJJz77777TT\ta66qEys7TTTTT77777777777777YyEqEj|~```             ``   ~%_.?b
//            |77T\7777i;?jRSs5wbRgi_;JtttttttJJz777yqb65J7777777777777zzzzzzzJJJJJJJJJJsoq6}!``             .` ~b;Di!
//           \TT\iT777+;7tRBbg}Eyz~;7ttttttttttJJ}UDX}zzzJJJJJJJJJJJttttttttttttttttttttttttfU6i.`             `` ~!~';\a,
//         .ii\iiiT7\;+7ggky6#8a;~7JtttttttttttyDDyJttttttzi?<=^^=*iztttttttttttttttJtttttttttJoDz.`             ` '=X75m
//        .LLiLLi\T|,?77yB&ggfi,?JJJJttttttttYbgytttttL^~'```````````',~;;!!!!;;~,'...',;^|777777mb;``             `  Q= `?S
//        ??|?|ii\*,|5&WbDQbt!,7zJJtJJJttttt}WXtttJ7;.`````````````````````````````````````.~<77TTtR|```            `  7awW~       `
//       **???Lii=,L\TtEg%o7,!7777zJJJJJJJtf#y777i~                                 ``````````'riii\D?````              +Qziyw,    ```
//      =<**?|L?*'|X8RDDKw7'=7777777zJJJJJtWE777*`                                              ~???LWr..```             ,jS*`      ..`
//     ;+=<??|?*'<|Jb8KgY\'*7777777777zJJJkg\i\?`                                                ;===7W,...```            _r}R}U.   `',
//     ^^+*??**,;i5s}fKDi'=\TT7777777777zzW5||?'                                                 .r^^^Us''..````          'g`<' '    ',~
//    !!!=??*=~'LQmSW&S|,^ii\\TT777777777sQ\**r                                                   ;!;;TR,,,'...```         `., S5=    _~,
//   ';;^*??r^`^*&6Sw&y!~|Liii\\TT7777777}Q*++,                                                   ,;;~^Q!_,,'''..```        iU;g B    ,;^
//   ~;;=*?=!',r+*t5y\*.???|iiii\\TT77777}Q+!!`                                                   `,,,~Q^~~~,,'''..```       *t;       ;r;
//   ~~;*??!; !^^r+==<_;*????|Liii\\TT777tQr;;             `~,,..` `          ```..,,~.            ```,Q!;;~~_,,,''..```               ;=?
//  ,_~^*?+;'.!!!^^r+r'=***????|Liii\\TT77B?~~   ,;;;~;;~;;~!=Li7J^,'',~~~~,,,~?J7i|+!~;~~;;;;;;,     ;g;;;;~~~~,,,''..```             '<|;
//  ,,~=*?!~ ~;;!!^X7~,==<***????|Liii\\\7R7''~|=,````````````````;|=        ??~````````````````_*?,  ?D7*;;;;~~~~,,'''..```  ,\        *ii
//  ,,~*??~~ ~;;;;!!!';r+==<**?????|LiTXm7ma`yi;;;;;;;;;;;;;;;;;;;;;+S~~,,~~X!;;;;;;;;;;;;;;;;;;;;;s= mr`r6<;;;;~~~~,,'''..`  `'      ` ?Tt
//  '';*??,' ~~~;;;;!'!^^r+==<**?????|q7  'WwmiiiiiiiiiiiiiiiiiiiiiiiK     .6iiiiiiiiiiiiiiiiiiiiiiiq7W   ~q!!;;;;;~~~,,,''.` ``      . ?7},
// `'';??<,. _Tt^wm*;'!!!^^r+==<**????g;   bW5JJJJJJJJJJJJJJJJJJJJJJYy      KtJJJJJJJJJJJJJJJJJJJJJJ6qb   `g!!!!;;;;~~~~,,,'. .`._,`  . <Jf;
// ...!??=,``~QjbJqX~';;!!!^^r+==<***?D^   }gk7777777777777777777777q`      ;X7777777777777777777777KK|   _Kr^^!!!;;;;;~~~,,, '?D}Yb? . +sy<
// `..;?|='` ,!7?;7!~,;;;;!!!^^r+==<**mj   *8o=!!!!!!!!!!!!!!!!!!!rkL        |S!!!!!!!!!!!!!!!!!!!!\zg    }y=+r^^!!!;;;;;~~~, ,Xkqryb`'`<}a?
//  ``;?L*'` 'YKbjqf~,~~;;;;!!!^^r+==<i#.  !W.Y'                 ,i;`         fz'                 ~T_L    W|<==+r^^!!!;;;;;~~ ,=zy;7,`'`iyw=
//  ``~?L|.` 'baXQX},,~~~~;;;;!!!^^r++=5k  ,m! !~               !, !          `';;               ;~ Y'   KY?**<==+r^^!!!;;;;~ ~5QXt^,.,`J5k^
//   `'|ii'. .;+!^TS~,,_~~~~;;;;!!!^^r+=D*``_6   _,          ',`  ;            `  ',.         `,,   W   =q|??***<==+r^^!!!;;' !}QS&Q7','fSU~
//    `*ii_` `,TEURy,,_,,_~~~~;;;;!!!^^r7W.`.D`     `,,~;~,'     '              ``    ',~;~,,`     ~j   8ti|?????**==+r^^!!! ,7oT^;~,,,;yEX'``
//     !i\!`  'aXmbRt'~,,,,_~~~~;;;;;!!^^D*`.77                 ;                ;                 j~  !D\\ii|???***<==+r^^! !sqW#Dj~_,?oXY..`
//     'i\i`` `.,..','_,,,,,,_~~~~;;;;;!!iD<~!#                 ; `|t^      =<`  ;                 Q!~ibtTT\\ii|???***<==+r''LWQwJ\+~,;Ym6<''
//      =T7;   ,g}wEkL';'',,,,,_~~~~;;;;;!^T}jq|                      `   `~'`                    ;Rf}z77777T\\iiL????**<=^`rXKRQD7;~~*ykw~,,
//      ,77\`  `7s.`'~',~''',,,,,_~~~~;;;;;!!^<W                                                  UmJJJz77777TT\\ii|????**';ySfstfT;,!soUi~~`
//       =7J!   `,\,Bob;;,'''',,,,,_~~~~;;;;!!!}j                                                 QYtttJJz77777TT\iii|???!~75f5Uby^,;ijmo;;~
//       `7JJ'   !WiQ,k!.;'.'''',,,,,_~~~~;;;;!!b,                               ````            |KttttttJJz777777T\iiiL=_?JEDgqf+;,<Y5k*;;
//        ;ts7`   '!,````.;'..'''',,,,,_~~~~;;;;+b              ``` ``````  `~!!!!;,'`           XfttttttttJJz777777T\i*~LRBBbmy7!,<7fSY!!~
//         =Y}i      `,Js=';'...'''',,,,,_~~~~;;;?f           `   `'~;;!^r*f=!,'.'';!'          ;bYfs}sttttttJJz77777T?;iYaEkDRt<'=\syy=^!
//          i}f?     X<m\Sw`;,`...'''',,,,,_~~~~;;|}                   ````_+;~'`            `.,bJzY?stttttttttJJz777*^t8bUD#z|*'=L7}j*=r
//           ijyL    LK|7DL.,_~``....''',,,,,_~~~~;<y'`                     _;;~.          ,~~=K5^t<!ttttttttttttJJ7=*7jQWXyQj*'+?\JY|*<
//            iy5?    `~;=oQb`';.`....'''',,,,,__~~~=E=__'`                  =;;~.       ,|*?yK}};J=;Jtttttttttttt7=7z77}yE6}=.<*L7JL?*.
//             ?oa7`    a7=g!?f.;_```....''',,,,,_~~~;ja?<*+;,.``````````    '=;~~,        zbwzzt~t+!JJtttttttttJ??SRbYt7777;'?=*i7i|?`
//              ^amy'     bBX*;}^';,``.....'''',,,,_~~~=mwz777T*^;~__,,,,,,,,';=;~~~        \777<|i=tJJJttttttti*7tQ%DRBqzT,~?^=?\\ii
//               ,okk?    ,.^Uw~+S''~,``.....'''',,,,__~~r5UjtttttJ7i|*<===<?|\Y=;~;~`       7Y7tzzzJJJJJJJJJ|*7UU}}5yRRo=.*^;^*i7T?
//                 zXX5,    ^';D85aX`'~,```....'''',,,,_~~~!YEk}77777TTTTT\\\\\\tr;~~;'   `Lf5Y777777zJJJJz??zXYfKQUwUt7,~*~;!=\77;
//                  ;E6q?     t7!,DfE}~,,,.``....''',,,,,,~~~~^z5mosi???******<|tkr;~;;;<'    .z7777777z\**tYqQDttaQKY~'*;,~;?zz7
//                    *6Kq*      5QS,'Qa'',,,.`....'''',,,,,_~~~~;!?Jfjjyyyyyyoyz|7=T^,        y77777|==LEXq&QKQ6J}t~'=;'',^7tJ=
//                     `fDRb*    `'  wSyQm^_~,'''....'''',,,,,_~~~;;;;;!!!^^+===<**}?        .TTTT<r+?tKbDQDsjXRX7~,r;..'~itt7
//                       ,mgWRi     `mmr`'R%tD?`.'''...'''',,,,,_~~~;;;;;!!!^r++==<*iL~,.~^i7Lr!!^?wbDf7UQwWWsz?_,r~```,<JtJ.
//                         ,o8&8s,  `    o7!~Ew ````......'',,,,,__~~~;;;;;!!!^r+===<***r;~;;;=i\\JQ%KR6}KbX7;,~^,  `'rztt,
//                            L8QQ%i. ````*}f*`   ``?L`...`````````.'',,_~~~~~,,''',,,,~;=??Xy|Liii\jDRK7i;~;^_    _?JJ7.
//                              !6QQQb*` ```        `````.,kym\'?L+,',``````,''~|^LwUX}=<***????|Liiiz*;;;^;.   `~LzzL
//                                `|DQQQD7_ `...      ````'amY+'=|Q\iQ*#RJQ=gRoRb*QRa\B}==<**????|*!;;!^;'`  `,=777~
//                                    *UQ@@Qb7;``.'''`  ``*q5#!,LyQ;zQW=yQB~!WXQL;YqyEWir+====^!!!!r!_'.``.~*T77!
//                                       ;sg@@@@WaL;..'',,,,,.`;iz7'?U*,,Uk,_^Eo~;;=i?^!!!!!!^++!;~,,''~!*\\\~
//                                           !}D@@@@@Qby\^~,,,,_~~~~~;;~;;;;;;;;;;;!!!^+=***<+!;;~~;!=?|L*'
//                                               '+YbQ@@@@@@QBDXaft7i?|?**?||i\7JY}jjjjY7TL*=r^^^=<**r.
//                                                     .;<7o6%BQ@@QQQQQQQB&8WgRRDKXo}7i*+^!!!!^^;`
//                                                              `',~;!!+==+^!!;;~~,,_~~~~~'
//                                                                    ```...```
//                              ________               .__                   _________ __
//                              /  _____/_____    _____ |__| ____    ____    /   _____//  |______ _______  ______
//                              /   \  ___\__  \  /     \|  |/    \  / ___\   \_____  \\   __\__  \\_  __ \/  ___/
//                              \    \_\  \/ __ \|  Y Y  \  |   |  \/ /_/  >  /        \|  |  / __ \|  | \/\___ \
//                              \______  (____  /__|_|  /__|___|  /\___  /  /_______  /|__| (____  /__|  /____  >
//                                      \/     \/      \/        \//_____/           \/           \/           \/

contract GamingStars is BEP20Token('Gaming Stars', 'GAMES', 102_000_000 * 1e18) {

}
