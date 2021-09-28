/*
    Copyright (C) 2011 Fredrik Johansson

    This file is part of FLINT.

    FLINT is free software: you can redistribute it and/or modify it under
    the terms of the GNU Lesser General Public License (LGPL) as published
    by the Free Software Foundation; either version 2.1 of the License, or
    (at your option) any later version.  See <https://www.gnu.org/licenses/>.
*/

#include <math.h>
#include "arith.h"

/* This nice round number precisely fits on 32 bits */
#define NUMBER_OF_SMALL_PARTITIONS 128

FLINT_DLL const unsigned int
partitions_lookup[NUMBER_OF_SMALL_PARTITIONS] = 
{
    UWORD(1),UWORD(1),UWORD(2),UWORD(3),UWORD(5),UWORD(7),UWORD(11),UWORD(15),UWORD(22),UWORD(30),UWORD(42),UWORD(56),UWORD(77),UWORD(101),UWORD(135),
    UWORD(176),UWORD(231),UWORD(297),UWORD(385),UWORD(490),UWORD(627),UWORD(792),UWORD(1002),UWORD(1255),UWORD(1575),UWORD(1958),
    UWORD(2436),UWORD(3010),UWORD(3718),UWORD(4565),UWORD(5604),UWORD(6842),UWORD(8349),UWORD(10143),UWORD(12310),UWORD(14883),
    UWORD(17977),UWORD(21637),UWORD(26015),UWORD(31185),UWORD(37338),UWORD(44583),UWORD(53174),UWORD(63261),UWORD(75175),
    UWORD(89134),UWORD(105558),UWORD(124754),UWORD(147273),UWORD(173525),UWORD(204226),UWORD(239943),UWORD(281589),
    UWORD(329931),UWORD(386155),UWORD(451276),UWORD(526823),UWORD(614154),UWORD(715220),UWORD(831820),UWORD(966467),
    UWORD(1121505),UWORD(1300156),UWORD(1505499),UWORD(1741630),UWORD(2012558),UWORD(2323520),UWORD(2679689),
    UWORD(3087735),UWORD(3554345),UWORD(4087968),UWORD(4697205),UWORD(5392783),UWORD(6185689),UWORD(7089500),
    UWORD(8118264),UWORD(9289091),UWORD(10619863),UWORD(12132164),UWORD(13848650),UWORD(15796476),UWORD(18004327),
    UWORD(20506255),UWORD(23338469),UWORD(26543660),UWORD(30167357),UWORD(34262962),UWORD(38887673),
    UWORD(44108109),UWORD(49995925),UWORD(56634173),UWORD(64112359),UWORD(72533807),UWORD(82010177),
    UWORD(92669720),UWORD(104651419),UWORD(118114304),UWORD(133230930),UWORD(150198136),UWORD(169229875),
    UWORD(190569292),UWORD(214481126),UWORD(241265379),UWORD(271248950),UWORD(304801365),UWORD(342325709),
    UWORD(384276336),UWORD(431149389),UWORD(483502844),UWORD(541946240),UWORD(607163746),UWORD(679903203),
    UWORD(761002156),UWORD(851376628),UWORD(952050665),UWORD(1064144451),UWORD(1188908248),UWORD(1327710076),
    UWORD(1482074143),UWORD(1653668665),UWORD(1844349560),UWORD(2056148051),UWORD(2291320912),
    UWORD(2552338241),UWORD(2841940500),UWORD(3163127352),UWORD(3519222692),UWORD(3913864295)
};

void
arith_number_of_partitions(fmpz_t x, ulong n)
{
    if (n < NUMBER_OF_SMALL_PARTITIONS)
    {
        fmpz_set_ui(x, partitions_lookup[n]);
    }
    else
    {
        mpfr_t t;
        mpfr_init(t);
        arith_number_of_partitions_mpfr(t, n);
        mpfr_get_z(_fmpz_promote(x), t, MPFR_RNDN);
        _fmpz_demote_val(x);
        mpfr_clear(t);
    }
}
