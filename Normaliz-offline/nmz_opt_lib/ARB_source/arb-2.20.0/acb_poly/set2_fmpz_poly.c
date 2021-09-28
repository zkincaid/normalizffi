/*
    Copyright (C) 2012 Fredrik Johansson

    This file is part of Arb.

    Arb is free software: you can redistribute it and/or modify it under
    the terms of the GNU Lesser General Public License (LGPL) as published
    by the Free Software Foundation; either version 2.1 of the License, or
    (at your option) any later version.  See <http://www.gnu.org/licenses/>.
*/

#include "acb_poly.h"

void
acb_poly_set2_fmpz_poly(acb_poly_t poly, const fmpz_poly_t re, const fmpz_poly_t im, slong prec)
{
    arb_poly_t t, u;
    arb_poly_init(t);
    arb_poly_init(u);

    arb_poly_set_fmpz_poly(t, re, prec);
    arb_poly_set_fmpz_poly(u, im, prec);

    acb_poly_set2_arb_poly(poly, t, u);

    arb_poly_clear(t);
    arb_poly_clear(u);
}
