/*-*- compile-command: "clang -c -o precomp.gp.o -O3 -Wall -fno-strict-aliasing -fomit-frame-pointer -fPIC -I\"/usr/local/Cellar/pari/2.11.0/include\" precomp.gp.c && clang -o precomp.gp.so -bundle -undefined dynamic_lookup -O3 -Wall -fno-strict-aliasing -fomit-frame-pointer -fPIC precomp.gp.o "; -*-*/
#include <pari/pari.h>
/*
GP;install("init_precomp","vp","init_precomp","./precomp.gp.so");
*/
void init_precomp(long prec);
/*End of prototype*/

static GEN brv;
static GEN q;
static GEN n;
static GEN mont;
static GEN g;
static GEN zetas;
static GEN omegas_inv_bitrev_montgomery;
static GEN psis_inv_montgomery;
/*End of global vars*/

void
init_precomp(long prec)	  /* void */
{
  GEN p1;	  /* vec */
  GEN p2;
  GEN p3;	  /* vec */
  GEN p4;
  GEN p5, p6;	  /* vec */
  brv = pol_x(fetch_user_var("brv"));
  q = pol_x(fetch_user_var("q"));
  n = pol_x(fetch_user_var("n"));
  mont = pol_x(fetch_user_var("mont"));
  g = pol_x(fetch_user_var("g"));
  zetas = pol_x(fetch_user_var("zetas"));
  omegas_inv_bitrev_montgomery = pol_x(fetch_user_var("omegas_inv_bitrev_montgomery"));
  psis_inv_montgomery = pol_x(fetch_user_var("psis_inv_montgomery"));
  p1 = cgetg(257, t_VEC);
  gel(p1, 1) = gen_0;
  gel(p1, 2) = stoi(128);
  gel(p1, 3) = stoi(64);
  gel(p1, 4) = stoi(192);
  gel(p1, 5) = stoi(32);
  gel(p1, 6) = stoi(160);
  gel(p1, 7) = stoi(96);
  gel(p1, 8) = stoi(224);
  gel(p1, 9) = stoi(16);
  gel(p1, 10) = stoi(144);
  gel(p1, 11) = stoi(80);
  gel(p1, 12) = stoi(208);
  gel(p1, 13) = stoi(48);
  gel(p1, 14) = stoi(176);
  gel(p1, 15) = stoi(112);
  gel(p1, 16) = stoi(240);
  gel(p1, 17) = stoi(8);
  gel(p1, 18) = stoi(136);
  gel(p1, 19) = stoi(72);
  gel(p1, 20) = stoi(200);
  gel(p1, 21) = stoi(40);
  gel(p1, 22) = stoi(168);
  gel(p1, 23) = stoi(104);
  gel(p1, 24) = stoi(232);
  gel(p1, 25) = stoi(24);
  gel(p1, 26) = stoi(152);
  gel(p1, 27) = stoi(88);
  gel(p1, 28) = stoi(216);
  gel(p1, 29) = stoi(56);
  gel(p1, 30) = stoi(184);
  gel(p1, 31) = stoi(120);
  gel(p1, 32) = stoi(248);
  gel(p1, 33) = stoi(4);
  gel(p1, 34) = stoi(132);
  gel(p1, 35) = stoi(68);
  gel(p1, 36) = stoi(196);
  gel(p1, 37) = stoi(36);
  gel(p1, 38) = stoi(164);
  gel(p1, 39) = stoi(100);
  gel(p1, 40) = stoi(228);
  gel(p1, 41) = stoi(20);
  gel(p1, 42) = stoi(148);
  gel(p1, 43) = stoi(84);
  gel(p1, 44) = stoi(212);
  gel(p1, 45) = stoi(52);
  gel(p1, 46) = stoi(180);
  gel(p1, 47) = stoi(116);
  gel(p1, 48) = stoi(244);
  gel(p1, 49) = stoi(12);
  gel(p1, 50) = stoi(140);
  gel(p1, 51) = stoi(76);
  gel(p1, 52) = stoi(204);
  gel(p1, 53) = stoi(44);
  gel(p1, 54) = stoi(172);
  gel(p1, 55) = stoi(108);
  gel(p1, 56) = stoi(236);
  gel(p1, 57) = stoi(28);
  gel(p1, 58) = stoi(156);
  gel(p1, 59) = stoi(92);
  gel(p1, 60) = stoi(220);
  gel(p1, 61) = stoi(60);
  gel(p1, 62) = stoi(188);
  gel(p1, 63) = stoi(124);
  gel(p1, 64) = stoi(252);
  gel(p1, 65) = gen_2;
  gel(p1, 66) = stoi(130);
  gel(p1, 67) = stoi(66);
  gel(p1, 68) = stoi(194);
  gel(p1, 69) = stoi(34);
  gel(p1, 70) = stoi(162);
  gel(p1, 71) = stoi(98);
  gel(p1, 72) = stoi(226);
  gel(p1, 73) = stoi(18);
  gel(p1, 74) = stoi(146);
  gel(p1, 75) = stoi(82);
  gel(p1, 76) = stoi(210);
  gel(p1, 77) = stoi(50);
  gel(p1, 78) = stoi(178);
  gel(p1, 79) = stoi(114);
  gel(p1, 80) = stoi(242);
  gel(p1, 81) = stoi(10);
  gel(p1, 82) = stoi(138);
  gel(p1, 83) = stoi(74);
  gel(p1, 84) = stoi(202);
  gel(p1, 85) = stoi(42);
  gel(p1, 86) = stoi(170);
  gel(p1, 87) = stoi(106);
  gel(p1, 88) = stoi(234);
  gel(p1, 89) = stoi(26);
  gel(p1, 90) = stoi(154);
  gel(p1, 91) = stoi(90);
  gel(p1, 92) = stoi(218);
  gel(p1, 93) = stoi(58);
  gel(p1, 94) = stoi(186);
  gel(p1, 95) = stoi(122);
  gel(p1, 96) = stoi(250);
  gel(p1, 97) = stoi(6);
  gel(p1, 98) = stoi(134);
  gel(p1, 99) = stoi(70);
  gel(p1, 100) = stoi(198);
  gel(p1, 101) = stoi(38);
  gel(p1, 102) = stoi(166);
  gel(p1, 103) = stoi(102);
  gel(p1, 104) = stoi(230);
  gel(p1, 105) = stoi(22);
  gel(p1, 106) = stoi(150);
  gel(p1, 107) = stoi(86);
  gel(p1, 108) = stoi(214);
  gel(p1, 109) = stoi(54);
  gel(p1, 110) = stoi(182);
  gel(p1, 111) = stoi(118);
  gel(p1, 112) = stoi(246);
  gel(p1, 113) = stoi(14);
  gel(p1, 114) = stoi(142);
  gel(p1, 115) = stoi(78);
  gel(p1, 116) = stoi(206);
  gel(p1, 117) = stoi(46);
  gel(p1, 118) = stoi(174);
  gel(p1, 119) = stoi(110);
  gel(p1, 120) = stoi(238);
  gel(p1, 121) = stoi(30);
  gel(p1, 122) = stoi(158);
  gel(p1, 123) = stoi(94);
  gel(p1, 124) = stoi(222);
  gel(p1, 125) = stoi(62);
  gel(p1, 126) = stoi(190);
  gel(p1, 127) = stoi(126);
  gel(p1, 128) = stoi(254);
  gel(p1, 129) = gen_1;
  gel(p1, 130) = stoi(129);
  gel(p1, 131) = stoi(65);
  gel(p1, 132) = stoi(193);
  gel(p1, 133) = stoi(33);
  gel(p1, 134) = stoi(161);
  gel(p1, 135) = stoi(97);
  gel(p1, 136) = stoi(225);
  gel(p1, 137) = stoi(17);
  gel(p1, 138) = stoi(145);
  gel(p1, 139) = stoi(81);
  gel(p1, 140) = stoi(209);
  gel(p1, 141) = stoi(49);
  gel(p1, 142) = stoi(177);
  gel(p1, 143) = stoi(113);
  gel(p1, 144) = stoi(241);
  gel(p1, 145) = stoi(9);
  gel(p1, 146) = stoi(137);
  gel(p1, 147) = stoi(73);
  gel(p1, 148) = stoi(201);
  gel(p1, 149) = stoi(41);
  gel(p1, 150) = stoi(169);
  gel(p1, 151) = stoi(105);
  gel(p1, 152) = stoi(233);
  gel(p1, 153) = stoi(25);
  gel(p1, 154) = stoi(153);
  gel(p1, 155) = stoi(89);
  gel(p1, 156) = stoi(217);
  gel(p1, 157) = stoi(57);
  gel(p1, 158) = stoi(185);
  gel(p1, 159) = stoi(121);
  gel(p1, 160) = stoi(249);
  gel(p1, 161) = stoi(5);
  gel(p1, 162) = stoi(133);
  gel(p1, 163) = stoi(69);
  gel(p1, 164) = stoi(197);
  gel(p1, 165) = stoi(37);
  gel(p1, 166) = stoi(165);
  gel(p1, 167) = stoi(101);
  gel(p1, 168) = stoi(229);
  gel(p1, 169) = stoi(21);
  gel(p1, 170) = stoi(149);
  gel(p1, 171) = stoi(85);
  gel(p1, 172) = stoi(213);
  gel(p1, 173) = stoi(53);
  gel(p1, 174) = stoi(181);
  gel(p1, 175) = stoi(117);
  gel(p1, 176) = stoi(245);
  gel(p1, 177) = stoi(13);
  gel(p1, 178) = stoi(141);
  gel(p1, 179) = stoi(77);
  gel(p1, 180) = stoi(205);
  gel(p1, 181) = stoi(45);
  gel(p1, 182) = stoi(173);
  gel(p1, 183) = stoi(109);
  gel(p1, 184) = stoi(237);
  gel(p1, 185) = stoi(29);
  gel(p1, 186) = stoi(157);
  gel(p1, 187) = stoi(93);
  gel(p1, 188) = stoi(221);
  gel(p1, 189) = stoi(61);
  gel(p1, 190) = stoi(189);
  gel(p1, 191) = stoi(125);
  gel(p1, 192) = stoi(253);
  gel(p1, 193) = stoi(3);
  gel(p1, 194) = stoi(131);
  gel(p1, 195) = stoi(67);
  gel(p1, 196) = stoi(195);
  gel(p1, 197) = stoi(35);
  gel(p1, 198) = stoi(163);
  gel(p1, 199) = stoi(99);
  gel(p1, 200) = stoi(227);
  gel(p1, 201) = stoi(19);
  gel(p1, 202) = stoi(147);
  gel(p1, 203) = stoi(83);
  gel(p1, 204) = stoi(211);
  gel(p1, 205) = stoi(51);
  gel(p1, 206) = stoi(179);
  gel(p1, 207) = stoi(115);
  gel(p1, 208) = stoi(243);
  gel(p1, 209) = stoi(11);
  gel(p1, 210) = stoi(139);
  gel(p1, 211) = stoi(75);
  gel(p1, 212) = stoi(203);
  gel(p1, 213) = stoi(43);
  gel(p1, 214) = stoi(171);
  gel(p1, 215) = stoi(107);
  gel(p1, 216) = stoi(235);
  gel(p1, 217) = stoi(27);
  gel(p1, 218) = stoi(155);
  gel(p1, 219) = stoi(91);
  gel(p1, 220) = stoi(219);
  gel(p1, 221) = stoi(59);
  gel(p1, 222) = stoi(187);
  gel(p1, 223) = stoi(123);
  gel(p1, 224) = stoi(251);
  gel(p1, 225) = stoi(7);
  gel(p1, 226) = stoi(135);
  gel(p1, 227) = stoi(71);
  gel(p1, 228) = stoi(199);
  gel(p1, 229) = stoi(39);
  gel(p1, 230) = stoi(167);
  gel(p1, 231) = stoi(103);
  gel(p1, 232) = stoi(231);
  gel(p1, 233) = stoi(23);
  gel(p1, 234) = stoi(151);
  gel(p1, 235) = stoi(87);
  gel(p1, 236) = stoi(215);
  gel(p1, 237) = stoi(55);
  gel(p1, 238) = stoi(183);
  gel(p1, 239) = stoi(119);
  gel(p1, 240) = stoi(247);
  gel(p1, 241) = stoi(15);
  gel(p1, 242) = stoi(143);
  gel(p1, 243) = stoi(79);
  gel(p1, 244) = stoi(207);
  gel(p1, 245) = stoi(47);
  gel(p1, 246) = stoi(175);
  gel(p1, 247) = stoi(111);
  gel(p1, 248) = stoi(239);
  gel(p1, 249) = stoi(31);
  gel(p1, 250) = stoi(159);
  gel(p1, 251) = stoi(95);
  gel(p1, 252) = stoi(223);
  gel(p1, 253) = stoi(63);
  gel(p1, 254) = stoi(191);
  gel(p1, 255) = stoi(127);
  gel(p1, 256) = stoi(255);
  brv = p1;
  q = stoi(7681);
  n = stoi(256);
  mont = gmodulo(powis(gen_2, 18), q);
  g = gen_0;
  p2 = gsubgs(q, 1);
  {
    GEN i;
    for (i = gen_2; gcmp(i, p2) <= 0; i = gaddgs(i, 1))
    {
      if (gequal(order(gmodulo(i, q)), gmulsg(2, n)))
      {
        g = gmodulo(i, q);
        break;
      }
    }
  }
  {
    long i;
    p3 = cgetg(gtos(n)+1, t_VEC);
    for (i = 1; gcmpsg(i, n) <= 0; ++i)
      gel(p3, i) = gmul(gpow(g, gel(brv, i), prec), mont);
  }
  zetas = lift(p3);
  p4 = gdivgs(n, 2);
  {
    long i;
    p5 = cgetg(gtos(p4)+1, t_VEC);
    for (i = 1; gcmpsg(i, p4) <= 0; ++i)
      gel(p5, i) = gmul(gpow(gsqr(g), gneg(gel(brv, (2*(i - 1)) + 1)), prec), mont);
  }
  omegas_inv_bitrev_montgomery = lift(p5);
  {
    long i;
    p6 = cgetg(gtos(n)+1, t_VEC);
    for (i = 1; gcmpsg(i, n) <= 0; ++i)
      gel(p6, i) = gmul(gdiv(gpowgs(g, -(i - 1)), n), mont);
  }
  psis_inv_montgomery = lift(p6);
  return;
}

