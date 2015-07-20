dnl This is m4 source.
dnl Process using m4 to produce 'C' language file.
dnl
dnl If you see this line, you can ignore the next one.
/* Do not edit this file. It is produced from the corresponding .m4 source */
dnl
/*********************************************************************
 *   Copyright 1996, UCAR/Unidata
 *   See netcdf/COPYRIGHT file for copying and redistribution conditions.
 *   $Id: test_put.m4 2785 2014-10-26 05:21:20Z wkliao $
 *********************************************************************/

// #define TEST_PNETCDF
#ifdef USE_PARALLEL
#include <mpi.h>
#endif

undefine(`index')dnl
dnl dnl dnl
dnl
dnl Macros
dnl
dnl dnl dnl
dnl
dnl Upcase(str)
dnl
define(`Upcase',dnl
`dnl
translit($1, abcdefghijklmnopqrstuvwxyz, ABCDEFGHIJKLMNOPQRSTUVWXYZ)')dnl
dnl dnl dnl
dnl
dnl NCT_ITYPE(type)
dnl
define(`NCT_ITYPE', ``NCT_'Upcase($1)')dnl
dnl

#include "tests.h"

dnl HASH(TYPE)
dnl
define(`HASH',dnl
`dnl
/*
 *  ensure hash value within range for internal TYPE
 */
static
double
hash_$1(
    const nc_type type,
    const int rank,
    const size_t *index,
    const nct_itype itype)
{
    const double min = $1_min;
    const double max = $1_max;

    return MAX(min, MIN(max, hash4( type, rank, index, itype)));
}
')dnl

HASH(text)
HASH(uchar)
HASH(schar)
HASH(short)
HASH(int)
HASH(long)
HASH(float)
HASH(double)
HASH(ushort)
HASH(uint)
HASH(longlong)
HASH(ulonglong)


dnl CHECK_VARS(TYPE)
dnl
define(`CHECK_VARS',dnl
`dnl
/*
 *  check all vars in file which are (text/numeric) compatible with TYPE
 */
static
void
check_vars_$1(const char *filename)
{
    int  ncid;                  /* netCDF id */
    size_t index[MAX_RANK];
    int  err;           /* status */
    int  d;
    int  i;
    size_t  j;
    $1 value;
    nc_type datatype;
    int ndims;
    int dimids[MAX_RANK];
    double expect;
    char name[NC_MAX_NAME];
    size_t length;
    int canConvert;     /* Both text or both numeric */
    int nok = 0;      /* count of valid comparisons */

#ifdef TEST_PNETCDF
    err = nc_open_par(filename, NC_NOWRITE|NC_PNETCDF, MPI_COMM_WORLD, MPI_INFO_NULL, &ncid);
#else
    err = nc_open(filename, NC_NOWRITE, &ncid);
#endif
    IF (err)
        error("nc_open: %s", nc_strerror(err));

    for (i = 0; i < numVars; i++) {
	canConvert = (var_type[i] == NC_CHAR) == (NCT_ITYPE($1) == NCT_TEXT);
	if (canConvert) {
	    err = nc_inq_var(ncid, i, name, &datatype, &ndims, dimids, NULL);
	    IF (err)
		error("nc_inq_var: %s", nc_strerror(err));
	    IF (strcmp(name, var_name[i]) != 0)
		error("Unexpected var_name");
	    IF (datatype != var_type[i])
		error("Unexpected type");
	    IF (ndims != var_rank[i])
		error("Unexpected rank");
	    for (j = 0; j < ndims; j++) {
		err = nc_inq_dim(ncid, dimids[j], 0, &length);
		IF (err)
		    error("nc_inq_dim: %s", nc_strerror(err));
		IF (length != var_shape[i][j])
		    error("Unexpected shape");
	    }
	    for (j = 0; j < var_nels[i]; j++) {
		err = toMixedBase(j, var_rank[i], var_shape[i], index);
		IF (err)
		    error("error in toMixedBase 2");
		expect = hash4( var_type[i], var_rank[i], index, NCT_ITYPE($1));
		err = nc_get_var1_$1(ncid, i, index, &value);
		if (inRange3(expect,datatype,NCT_ITYPE($1))) {
                    if (expect >= $1_min && expect <= $1_max) {
			IF (err) {
			    error("nc_get_var1_$1: %s", nc_strerror(err));
			} else {
                            IF (!equal(value,expect,var_type[i],NCT_ITYPE($1))) {
				error("Var value read not that expected");
				if (verbose) {
				    error("\n");
				    error("varid: %d, ", i);
				    error("var_name: %s, ", var_name[i]);
				    error("index:");
				    for (d = 0; d < var_rank[i]; d++)
					error(" %d", index[d]);
				    error(", expect: %g, ", expect);
				    error("got: %g", (double) value);
				}
			    } else {
				++nok;
			    }
			}
		    }
		}
	    }
	}
    }
    err = nc_close (ncid);
    IF (err)
        error("nc_close: %s", nc_strerror(err));
    print_nok(nok);
}
')dnl

CHECK_VARS(text)
CHECK_VARS(uchar)
CHECK_VARS(schar)
CHECK_VARS(short)
CHECK_VARS(int)
CHECK_VARS(long)
CHECK_VARS(float)
CHECK_VARS(double)
CHECK_VARS(ushort)
CHECK_VARS(uint)
CHECK_VARS(longlong)
CHECK_VARS(ulonglong)


dnl CHECK_ATTS(TYPE)         numeric only
dnl
define(`CHECK_ATTS',dnl
`dnl
/*
 *  check all attributes in file which are (text/numeric) compatible with TYPE
 *  ignore any attributes containing values outside range of TYPE
 */
static
void
check_atts_$1(int  ncid)
{
    int  err;           /* status */
    int  i;
    int  j;
    size_t  k;
    $1 value[MAX_NELS];
    nc_type datatype;
    double expect[MAX_NELS];
    size_t length;
    size_t nInExtRange;  /* number values within external range */
    size_t nInIntRange;  /* number values within internal range */
    int canConvert;     /* Both text or both numeric */
    int nok = 0;      /* count of valid comparisons */

    for (i = -1; i < numVars; i++) {
        for (j = 0; j < NATTS(i); j++) {
	    canConvert = (ATT_TYPE(i,j) == NC_CHAR) == (NCT_ITYPE($1) == NCT_TEXT);
	    if (canConvert) {
		err = nc_inq_att(ncid, i, ATT_NAME(i,j), &datatype, &length);
		IF (err)
		    error("nc_inq_att: %s", nc_strerror(err));
		IF (datatype != ATT_TYPE(i,j))
		error("nc_inq_att: unexpected type");
		IF (length != ATT_LEN(i,j))
		    error("nc_inq_att: unexpected length");
		assert(length <= MAX_NELS);
		nInIntRange = nInExtRange = 0;
		for (k = 0; k < length; k++) {
		    expect[k] = hash4( datatype, -1, &k, NCT_ITYPE($1));
		    if (inRange3(expect[k], datatype, NCT_ITYPE($1))) {
			++nInExtRange;
			if (expect[k] >= $1_min && expect[k] <= $1_max)
			    ++nInIntRange;
		    }
		}
		err = nc_get_att_$1(ncid, i, ATT_NAME(i,j), value);
                if (nInExtRange == length && nInIntRange == length) {
		    IF (err)
			error("%s", nc_strerror(err));
                } else {
                    IF (err != 0 && err != NC_ERANGE)
                        error("OK or Range error: status = %d", err);
                }
		for (k = 0; k < length; k++) {
                    if (inRange3(expect[k],datatype,NCT_ITYPE($1))
                            && expect[k] >= $1_min && expect[k] <= $1_max) {
                        IF (!equal(value[k],expect[k],datatype,NCT_ITYPE($1))) {
                            error("att. value read not that expected");
                            if (verbose) {
                                error("\n");
                                error("varid: %d, ", i);
                                error("att_name: %s, ", ATT_NAME(i,j));
                                error("element number: %d ", k);
                                error("expect: %g, ", expect[k]);
                                error("got: %g", (double) value[k]);
                            }
                        } else {
                            nok++;
                        }
                    }
                }
            }
        }
    }

    print_nok(nok);
}
')dnl

CHECK_ATTS(text)
CHECK_ATTS(uchar)
CHECK_ATTS(schar)
CHECK_ATTS(short)
CHECK_ATTS(int)
CHECK_ATTS(long)
CHECK_ATTS(float)
CHECK_ATTS(double)
CHECK_ATTS(ushort)
CHECK_ATTS(uint)
CHECK_ATTS(longlong)
CHECK_ATTS(ulonglong)


dnl TEST_NC_PUT_VAR1(TYPE)
dnl
define(`TEST_NC_PUT_VAR1',dnl
`dnl
void
test_nc_put_var1_$1(void)
{
    int ncid;
    int i;
    int j;
    int err;
    size_t index[MAX_RANK];
    int canConvert;	/* Both text or both numeric */
    $1 value = 5;	/* any value would do - only for error cases */

#ifdef TEST_PNETCDF
    err = nc_create_par(scratch, NC_CLOBBER|NC_PNETCDF, MPI_COMM_WORLD, MPI_INFO_NULL, &ncid);
#else
    err = nc_create(scratch, NC_CLOBBER, &ncid);
#endif
    IF (err) {
        error("nc_create: %s", nc_strerror(err));
        return;
    }
    def_dims(ncid);
    def_vars(ncid);
    err = nc_enddef(ncid);
    IF (err)
        error("nc_enddef: %s", nc_strerror(err));

    for (i = 0; i < numVars; i++) {
	canConvert = (var_type[i] == NC_CHAR) == (NCT_ITYPE($1) == NCT_TEXT);
        for (j = 0; j < var_rank[i]; j++)
            index[j] = 0;
        err = nc_put_var1_$1(BAD_ID, i, index, &value);
        IF (err != NC_EBADID)
	    error("bad ncid: status = %d", err);
        err = nc_put_var1_$1(ncid, BAD_VARID, index, &value);
        IF (err != NC_ENOTVAR)
	    error("bad var id: status = %d", err);
        for (j = 0; j < var_rank[i]; j++) {
	    if (var_dimid[i][j] > 0) {		/* skip record dim */
		index[j] = var_shape[i][j];
		err = nc_put_var1_$1(ncid, i, index, &value);
		IF (canConvert && err != NC_EINVALCOORDS)
		    error("bad index: status = %d", err);
		index[j] = 0;
	    }
        }
        for (j = 0; j < var_nels[i]; j++) {
            err = toMixedBase(j, var_rank[i], var_shape[i], index);
            IF (err)
		error("error in toMixedBase 1");
            value = hash_$1( var_type[i], var_rank[i], index, NCT_ITYPE($1));
	    if (var_rank[i] == 0 && i%2 == 0)
		err = nc_put_var1_$1(ncid, i, NULL, &value);
	    else
		err = nc_put_var1_$1(ncid, i, index, &value);
	    if (canConvert) {
		if (inRange3(value, var_type[i],NCT_ITYPE($1))) {
		    IF (err)
			error("%s", nc_strerror(err));
		} else {
		    IF (err != NC_ERANGE) {
			error("Range error: status = %d", err);
			error("\n\t\tfor type %s value %.17e %ld",
				s_nc_type(var_type[i]),
				(double)value, (long)value);
		    }
		}
	    } else {
		IF (err != NC_ECHAR)
		    error("wrong type: status = %d", err);
            }
        }
    }

    err = nc_close(ncid);
    IF (err)
	error("nc_close: %s", nc_strerror(err));

    check_vars_$1(scratch);

    err = remove(scratch);
    IF (err)
        error("remove of %s failed", scratch);
}
')dnl

TEST_NC_PUT_VAR1(text)
TEST_NC_PUT_VAR1(uchar)
TEST_NC_PUT_VAR1(schar)
TEST_NC_PUT_VAR1(short)
TEST_NC_PUT_VAR1(int)
TEST_NC_PUT_VAR1(long)
TEST_NC_PUT_VAR1(float)
TEST_NC_PUT_VAR1(double)
TEST_NC_PUT_VAR1(ushort)
TEST_NC_PUT_VAR1(uint)
TEST_NC_PUT_VAR1(longlong)
TEST_NC_PUT_VAR1(ulonglong)


dnl TEST_NC_PUT_VAR(TYPE)
dnl
define(`TEST_NC_PUT_VAR',dnl
`dnl
void
test_nc_put_var_$1(void)
{
    int ncid;
    int varid;
    int i;
    int j;
    int err;
    int nels;
    size_t index[MAX_RANK];
    int canConvert;	/* Both text or both numeric */
    int allInExtRange;	/* all values within external range? */
    $1 value[MAX_NELS];

#ifdef TEST_PNETCDF
    err = nc_create_par(scratch, NC_CLOBBER|NC_PNETCDF, MPI_COMM_WORLD, MPI_INFO_NULL, &ncid);
#else
    err = nc_create(scratch, NC_CLOBBER, &ncid);
#endif
    IF (err) {
        error("nc_create: %s", nc_strerror(err));
        return;
    }
    def_dims(ncid);
    def_vars(ncid);
    err = nc_enddef(ncid);
    IF (err)
        error("nc_enddef: %s", nc_strerror(err));

    for (i = 0; i < numVars; i++) {
	canConvert = (var_type[i] == NC_CHAR) == (NCT_ITYPE($1) == NCT_TEXT);
        assert(var_rank[i] <= MAX_RANK);
        assert(var_nels[i] <= MAX_NELS);
        err = nc_put_var_$1(BAD_ID, i, value);
        IF (err != NC_EBADID)
	    error("bad ncid: status = %d", err);
        err = nc_put_var_$1(ncid, BAD_VARID, value);
        IF (err != NC_ENOTVAR)
	    error("bad var id: status = %d", err);

	nels = 1;
	for (j = 0; j < var_rank[i]; j++) {
	    nels *= var_shape[i][j];
	}
	for (allInExtRange = 1, j = 0; j < nels; j++) {
	    err = toMixedBase(j, var_rank[i], var_shape[i], index);
	    IF (err)
		error("error in toMixedBase 1");
	    value[j]= hash_$1(var_type[i], var_rank[i], index, NCT_ITYPE($1));
	    allInExtRange = allInExtRange
		&& inRange3(value[j], var_type[i], NCT_ITYPE($1));
	}
        err = nc_put_var_$1(ncid, i, value);
	if (canConvert) {
	    if (allInExtRange) {
		IF (err)
		    error("%s", nc_strerror(err));
	    } else {
		IF (err != NC_ERANGE && var_dimid[i][0] != RECDIM)
		    error("range error: status = %d", err);
	    }
	} else {       /* should flag wrong type even if nothing to write */
	    IF (nels > 0 && err != NC_ECHAR)
		error("wrong type: status = %d", err);
	}
    }

        /* Preceeding has written nothing for record variables, now try */
        /* again with more than 0 records */

	/* Write record number NRECS to force writing of preceding records */
	/* Assumes variable cr is char vector with UNLIMITED dimension */
    err = nc_inq_varid(ncid, "cr", &varid);
    IF (err)
        error("nc_inq_varid: %s", nc_strerror(err));
    index[0] = NRECS-1;
    err = nc_put_var1_text(ncid, varid, index, "x");
    IF (err)
        error("nc_put_var1_text: %s", nc_strerror(err));

    for (i = 0; i < numVars; i++) {
        if (var_dimid[i][0] == RECDIM) {  /* only test record variables here */
	    canConvert = (var_type[i] == NC_CHAR) == (NCT_ITYPE($1) == NCT_TEXT);
	    assert(var_rank[i] <= MAX_RANK);
	    assert(var_nels[i] <= MAX_NELS);
	    err = nc_put_var_$1(BAD_ID, i, value);
	    IF (err != NC_EBADID)
	        error("bad ncid: status = %d", err);
	    nels = 1;
	    for (j = 0; j < var_rank[i]; j++) {
		nels *= var_shape[i][j];
	    }
	    for (allInExtRange = 1, j = 0; j < nels; j++) {
		err = toMixedBase(j, var_rank[i], var_shape[i], index);
		IF (err)
		    error("error in toMixedBase 1");
		value[j]= hash_$1(var_type[i], var_rank[i], index, NCT_ITYPE($1));
		allInExtRange = allInExtRange
		    && inRange3(value[j], var_type[i], NCT_ITYPE($1));
	    }
	    err = nc_put_var_$1(ncid, i, value);
	    if (canConvert) {
		if (allInExtRange) {
		    IF (err)
			error("%s", nc_strerror(err));
		} else {
		    IF (err != NC_ERANGE)
			error("range error: status = %d", err);
		}
	    } else {
		IF (nels > 0 && err != NC_ECHAR)
		    error("wrong type: status = %d", err);
	    }
        }
    }

    err = nc_close(ncid);
    IF (err)
	error("nc_close: %s", nc_strerror(err));

    check_vars_$1(scratch);

    err = remove(scratch);
    IF (err)
        error("remove of %s failed", scratch);
}
')dnl

TEST_NC_PUT_VAR(text)
TEST_NC_PUT_VAR(uchar)
TEST_NC_PUT_VAR(schar)
TEST_NC_PUT_VAR(short)
TEST_NC_PUT_VAR(int)
TEST_NC_PUT_VAR(long)
TEST_NC_PUT_VAR(float)
TEST_NC_PUT_VAR(double)
TEST_NC_PUT_VAR(ushort)
TEST_NC_PUT_VAR(uint)
TEST_NC_PUT_VAR(longlong)
TEST_NC_PUT_VAR(ulonglong)


dnl TEST_NC_PUT_VARA(TYPE)
dnl
define(`TEST_NC_PUT_VARA',dnl
`dnl
void
test_nc_put_vara_$1(void)
{
    int ncid;
    int d;
    int i;
    int j;
    int k;
    int err;
    int nslabs;
    int nels;
    size_t start[MAX_RANK];
    size_t edge[MAX_RANK];
    size_t mid[MAX_RANK];
    size_t index[MAX_RANK];
    int canConvert;	/* Both text or both numeric */
    int allInExtRange;	/* all values within external range? */
    $1 value[MAX_NELS];

#ifdef TEST_PNETCDF
    err = nc_create_par(scratch, NC_CLOBBER|NC_PNETCDF, MPI_COMM_WORLD, MPI_INFO_NULL, &ncid);
#else
    err = nc_create(scratch, NC_CLOBBER, &ncid);
#endif
    IF (err) {
        error("nc_create: %s", nc_strerror(err));
        return;
    }
    def_dims(ncid);
    def_vars(ncid);
    err = nc_enddef(ncid);
    IF (err)
        error("nc_enddef: %s", nc_strerror(err));

    value[0] = 0;
    for (i = 0; i < numVars; i++) {
	canConvert = (var_type[i] == NC_CHAR) == (NCT_ITYPE($1) == NCT_TEXT);
        assert(var_rank[i] <= MAX_RANK);
        assert(var_nels[i] <= MAX_NELS);
        for (j = 0; j < var_rank[i]; j++) {
            start[j] = 0;
            edge[j] = 1;
	}
        err = nc_put_vara_$1(BAD_ID, i, start, edge, value);
        IF (err != NC_EBADID)
	    error("bad ncid: status = %d", err);
        err = nc_put_vara_$1(ncid, BAD_VARID, start, edge, value);
        IF (err != NC_ENOTVAR)
	    error("bad var id: status = %d", err);
        for (j = 0; j < var_rank[i]; j++) {
	    if (var_dimid[i][j] > 0) {		/* skip record dim */
		start[j] = var_shape[i][j];
		err = nc_put_vara_$1(ncid, i, start, edge, value);
		IF (canConvert && err != NC_EINVALCOORDS)
		    error("bad start: status = %d", err);
		start[j] = 0;
		edge[j] = var_shape[i][j] + 1;
		err = nc_put_vara_$1(ncid, i, start, edge, value);
		IF (canConvert && err != NC_EEDGE)
		    error("bad edge: status = %d", err);
		edge[j] = 1;
	    }
        }
            /* Check correct error returned even when nothing to put */
        for (j = 0; j < var_rank[i]; j++) {
            edge[j] = 0;
	}
        err = nc_put_vara_$1(BAD_ID, i, start, edge, value);
        IF (err != NC_EBADID)
	    error("bad ncid: status = %d", err);
        err = nc_put_vara_$1(ncid, BAD_VARID, start, edge, value);
        IF (err != NC_ENOTVAR)
	    error("bad var id: status = %d", err);
        for (j = 0; j < var_rank[i]; j++) {
	    if (var_dimid[i][j] > 0) {		/* skip record dim */
		start[j] = var_shape[i][j];
		err = nc_put_vara_$1(ncid, i, start, edge, value);
		IF (canConvert && err != NC_EINVALCOORDS)
		    error("bad start: status = %d", err);
		start[j] = 0;
	    }
        }

/* wkliao: this test below of put_vara is redundant and incorrectly uses the
           value[] set from the previously iteration. There is no such test
           in put_vars and put_varm.

	err = nc_put_vara_$1(ncid, i, start, edge, value);
	if (canConvert) {
	    IF (err)
		error("%s", nc_strerror(err));
	} else {
	    IF (err != NC_ECHAR)
		error("wrong type: status = %d", err);
        }
*/
        for (j = 0; j < var_rank[i]; j++) {
            edge[j] = 1;
	}

	    /* Choose a random point dividing each dim into 2 parts */
	    /* Put 2^rank (nslabs) slabs so defined */
	nslabs = 1;
	for (j = 0; j < var_rank[i]; j++) {
            mid[j] = roll( var_shape[i][j] );
	    nslabs *= 2;
	}
	    /* bits of k determine whether to put lower or upper part of dim */
	for (k = 0; k < nslabs; k++) {
	    nels = 1;
	    for (j = 0; j < var_rank[i]; j++) {
		if ((k >> j) & 1) {
		    start[j] = 0;
		    edge[j] = mid[j];
		}else{
		    start[j] = mid[j];
		    edge[j] = var_shape[i][j] - mid[j];
		}
		nels *= edge[j];
	    }
            for (allInExtRange = 1, j = 0; j < nels; j++) {
		err = toMixedBase(j, var_rank[i], edge, index);
		IF (err)
		    error("error in toMixedBase 1");
		for (d = 0; d < var_rank[i]; d++)
		    index[d] += start[d];
		value[j]= hash_$1(var_type[i], var_rank[i], index, NCT_ITYPE($1));
		allInExtRange = allInExtRange
		    && inRange3(value[j], var_type[i], NCT_ITYPE($1));
	    }
	    if (var_rank[i] == 0 && i%2 == 0)
		err = nc_put_vara_$1(ncid, i, NULL, NULL, value);
	    else
		err = nc_put_vara_$1(ncid, i, start, edge, value);
	    if (canConvert) {
		if (allInExtRange) {
		    IF (err)
			error("%s", nc_strerror(err));
		} else {
		    IF (err != NC_ERANGE)
			error("range error: status = %d", err);
		}
	    } else {
		IF (nels > 0 && err != NC_ECHAR)
		    error("wrong type: status = %d", err);
            }
        }
    }

    err = nc_close(ncid);
    IF (err)
	error("nc_close: %s", nc_strerror(err));

    check_vars_$1(scratch);

    err = remove(scratch);
    IF (err)
        error("remove of %s failed", scratch);
}
')dnl

TEST_NC_PUT_VARA(text)
TEST_NC_PUT_VARA(uchar)
TEST_NC_PUT_VARA(schar)
TEST_NC_PUT_VARA(short)
TEST_NC_PUT_VARA(int)
TEST_NC_PUT_VARA(long)
TEST_NC_PUT_VARA(float)
TEST_NC_PUT_VARA(double)
TEST_NC_PUT_VARA(ushort)
TEST_NC_PUT_VARA(uint)
TEST_NC_PUT_VARA(longlong)
TEST_NC_PUT_VARA(ulonglong)


dnl TEST_NC_PUT_VARS(TYPE)
dnl
define(`TEST_NC_PUT_VARS',dnl
`dnl
void
test_nc_put_vars_$1(void)
{
    int ncid;
    int d;
    int i;
    int j;
    int k;
    int m;
    int err;
    int nels;
    int nslabs;
    int nstarts;        /* number of different starts */
    size_t start[MAX_RANK];
    size_t edge[MAX_RANK];
    size_t index[MAX_RANK];
    size_t index2[MAX_RANK];
    size_t mid[MAX_RANK];
    size_t count[MAX_RANK];
    size_t sstride[MAX_RANK];
    ptrdiff_t stride[MAX_RANK];
    int canConvert;	/* Both text or both numeric */
    int allInExtRange;	/* all values within external range? */
    $1 value[MAX_NELS];

#ifdef TEST_PNETCDF
    err = nc_create_par(scratch, NC_CLOBBER|NC_PNETCDF, MPI_COMM_WORLD, MPI_INFO_NULL, &ncid);
#else
    err = nc_create(scratch, NC_CLOBBER, &ncid);
#endif
    IF (err) {
	error("nc_create: %s", nc_strerror(err));
	return;
    }
    def_dims(ncid);
    def_vars(ncid);
    err = nc_enddef(ncid);
    IF (err)
	error("nc_enddef: %s", nc_strerror(err));

    for (i = 0; i < numVars; i++) {
	canConvert = (var_type[i] == NC_CHAR) == (NCT_ITYPE($1) == NCT_TEXT);
	assert(var_rank[i] <= MAX_RANK);
	assert(var_nels[i] <= MAX_NELS);
	for (j = 0; j < var_rank[i]; j++) {
	    start[j] = 0;
	    edge[j] = 1;
	    stride[j] = 1;
	}
	err = nc_put_vars_$1(BAD_ID, i, start, edge, stride, value);
	IF (err != NC_EBADID)
	    error("bad ncid: status = %d", err);
	err = nc_put_vars_$1(ncid, BAD_VARID, start, edge, stride, value);
	IF (err != NC_ENOTVAR)
	    error("bad var id: status = %d", err);
	for (j = 0; j < var_rank[i]; j++) {
	    if (var_dimid[i][j] > 0) {		/* skip record dim */
		start[j] = var_shape[i][j] + 1;
		err = nc_put_vars_$1(ncid, i, start, edge, stride, value);
	      if(!canConvert) {
		IF(err != NC_ECHAR)
			error("conversion: status = %d", err);
	      } else {
		IF(err != NC_EINVALCOORDS)
		    error("bad start: status = %d", err);
		start[j] = 0;
		edge[j] = var_shape[i][j] + 1;
		err = nc_put_vars_$1(ncid, i, start, edge, stride, value);
		IF (err != NC_EEDGE)
		    error("bad edge: status = %d", err);
		edge[j] = 1;
		stride[j] = 0;
		err = nc_put_vars_$1(ncid, i, start, edge, stride, value);
		IF (err != NC_ESTRIDE)
		    error("bad stride: status = %d", err);
		stride[j] = 1;
              }
	    }
	}
	    /* Choose a random point dividing each dim into 2 parts */
	    /* Put 2^rank (nslabs) slabs so defined */
	nslabs = 1;
	for (j = 0; j < var_rank[i]; j++) {
	    mid[j] = roll( var_shape[i][j] );
	    nslabs *= 2;
	}
	    /* bits of k determine whether to put lower or upper part of dim */
	    /* choose random stride from 1 to edge */
	for (k = 0; k < nslabs; k++) {
	    nstarts = 1;
	    for (j = 0; j < var_rank[i]; j++) {
		if ((k >> j) & 1) {
		    start[j] = 0;
		    edge[j] = mid[j];
		}else{
		    start[j] = mid[j];
		    edge[j] = var_shape[i][j] - mid[j];
		}
		sstride[j] = stride[j] = edge[j] > 0 ? 1+roll(edge[j]) : 1;
		nstarts *= stride[j];
	    }
	    for (m = 0; m < nstarts; m++) {
		err = toMixedBase(m, var_rank[i], sstride, index);
		IF (err)
		    error("error in toMixedBase");
		nels = 1;
		for (j = 0; j < var_rank[i]; j++) {
		    count[j] = 1 + (edge[j] - index[j] - 1) / stride[j];
		    nels *= count[j];
		    index[j] += start[j];
		}
		    /* Random choice of forward or backward */
/* TODO
		if ( roll(2) ) {
		    for (j = 0; j < var_rank[i]; j++) {
			index[j] += (count[j] - 1) * stride[j];
			stride[j] = -stride[j];
		    }
		}
*/
		for (allInExtRange = 1, j = 0; j < nels; j++) {
		    err = toMixedBase(j, var_rank[i], count, index2);
		    IF (err)
			error("error in toMixedBase");
		    for (d = 0; d < var_rank[i]; d++)
			index2[d] = index[d] + index2[d] * stride[d];
		    value[j] = hash_$1(var_type[i], var_rank[i], index2,
			NCT_ITYPE($1));
		    allInExtRange = allInExtRange
			&& inRange3(value[j], var_type[i], NCT_ITYPE($1));
		}
		if (var_rank[i] == 0 && i%2 == 0)
		    err = nc_put_vars_$1(ncid, i, NULL, NULL, stride, value);
		else
		    err = nc_put_vars_$1(ncid, i, index, count, stride, value);
		if (canConvert) {
		    if (allInExtRange) {
			IF (err)
			    error("%s", nc_strerror(err));
		    } else {
			IF (err != NC_ERANGE)
			    error("range error: status = %d", err);
		    }
		} else {
		    IF (nels > 0 && err != NC_ECHAR)
			error("wrong type: status = %d", err);
		}
	    }
	}
    }

    err = nc_close(ncid);
    IF (err)
	error("nc_close: %s", nc_strerror(err));

    check_vars_$1(scratch);

    err = remove(scratch);
    IF (err)
	error("remove of %s failed", scratch);
}
')dnl

TEST_NC_PUT_VARS(text)
TEST_NC_PUT_VARS(uchar)
TEST_NC_PUT_VARS(schar)
TEST_NC_PUT_VARS(short)
TEST_NC_PUT_VARS(int)
TEST_NC_PUT_VARS(long)
TEST_NC_PUT_VARS(float)
TEST_NC_PUT_VARS(double)
TEST_NC_PUT_VARS(ushort)
TEST_NC_PUT_VARS(uint)
TEST_NC_PUT_VARS(longlong)
TEST_NC_PUT_VARS(ulonglong)


dnl TEST_NC_PUT_VARM(TYPE)
dnl
define(`TEST_NC_PUT_VARM',dnl
`dnl
void
test_nc_put_varm_$1(void)
{
    int ncid;
    int d;
    int i;
    int j;
    int k;
    int m;
    int err;
    int nels;
    int nslabs;
    int nstarts;        /* number of different starts */
    size_t start[MAX_RANK];
    size_t edge[MAX_RANK];
    size_t index[MAX_RANK];
    size_t index2[MAX_RANK];
    size_t mid[MAX_RANK];
    size_t count[MAX_RANK];
    size_t sstride[MAX_RANK];
    ptrdiff_t stride[MAX_RANK];
    ptrdiff_t imap[MAX_RANK];
    int canConvert;	/* Both text or both numeric */
    int allInExtRange;	/* all values within external range? */
    $1 value[MAX_NELS];

#ifdef TEST_PNETCDF
    err = nc_create_par(scratch, NC_CLOBBER|NC_PNETCDF, MPI_COMM_WORLD, MPI_INFO_NULL, &ncid);
#else
    err = nc_create(scratch, NC_CLOBBER, &ncid);
#endif
    IF (err) {
	error("nc_create: %s", nc_strerror(err));
	return;
    }
    def_dims(ncid);
    def_vars(ncid);
    err = nc_enddef(ncid);
    IF (err)
	error("nc_enddef: %s", nc_strerror(err));

    for (i = 0; i < numVars; i++) {
	canConvert = (var_type[i] == NC_CHAR) == (NCT_ITYPE($1) == NCT_TEXT);
	assert(var_rank[i] <= MAX_RANK);
	assert(var_nels[i] <= MAX_NELS);
	for (j = 0; j < var_rank[i]; j++) {
	    start[j] = 0;
	    edge[j] = 1;
	    stride[j] = 1;
	    imap[j] = 1;
	}
	err = nc_put_varm_$1(BAD_ID, i, start, edge, stride, imap, value);
	IF (err != NC_EBADID)
	    error("bad ncid: status = %d", err);
	err = nc_put_varm_$1(ncid, BAD_VARID, start, edge, stride, imap, value);
	IF (err != NC_ENOTVAR)
	    error("bad var id: status = %d", err);
	for (j = 0; j < var_rank[i]; j++) {
	    if (var_dimid[i][j] > 0) {		/* skip record dim */
		start[j] = var_shape[i][j] + 1;
		err = nc_put_varm_$1(ncid, i, start, edge, stride, imap, value);
	      if (!canConvert) {
		IF(err != NC_ECHAR)
			error("conversion: status = %d", err);
	      } else {
		IF (err != NC_EINVALCOORDS)
		    error("bad start: status = %d", err);
		start[j] = 0;
		edge[j] = var_shape[i][j] + 1;
		err = nc_put_varm_$1(ncid, i, start, edge, stride, imap, value);
		IF (err != NC_EEDGE)
		    error("bad edge: status = %d", err);
		edge[j] = 1;
		stride[j] = 0;
		err = nc_put_varm_$1(ncid, i, start, edge, stride, imap, value);
		IF (err != NC_ESTRIDE)
		    error("bad stride: status = %d", err);
		stride[j] = 1;
	      }
	    }
	}
	    /* Choose a random point dividing each dim into 2 parts */
	    /* Put 2^rank (nslabs) slabs so defined */
	nslabs = 1;
	for (j = 0; j < var_rank[i]; j++) {
	    mid[j] = roll( var_shape[i][j] );
	    nslabs *= 2;
	}
	    /* bits of k determine whether to put lower or upper part of dim */
	    /* choose random stride from 1 to edge */
	for (k = 0; k < nslabs; k++) {
	    nstarts = 1;
	    for (j = 0; j < var_rank[i]; j++) {
		if ((k >> j) & 1) {
		    start[j] = 0;
		    edge[j] = mid[j];
		}else{
		    start[j] = mid[j];
		    edge[j] = var_shape[i][j] - mid[j];
		}
		sstride[j] = stride[j] = edge[j] > 0 ? 1+roll(edge[j]) : 1;
		nstarts *= stride[j];
	    }
            for (m = 0; m < nstarts; m++) {
                err = toMixedBase(m, var_rank[i], sstride, index);
                IF (err)
                    error("error in toMixedBase");
                nels = 1;
                for (j = 0; j < var_rank[i]; j++) {
                    count[j] = 1 + (edge[j] - index[j] - 1) / stride[j];
                    nels *= count[j];
                    index[j] += start[j];
                }
                    /* Random choice of forward or backward */
/* TODO
                if ( roll(2) ) {
                    for (j = 0; j < var_rank[i]; j++) {
                        index[j] += (count[j] - 1) * stride[j];
                        stride[j] = -stride[j];
                    }
                }
*/
                if (var_rank[i] > 0) {
                    j = var_rank[i] - 1;
                    imap[j] = 1;
                    for (; j > 0; j--)
                        imap[j-1] = imap[j] * count[j];
                }
                for (allInExtRange = 1, j = 0; j < nels; j++) {
                    err = toMixedBase(j, var_rank[i], count, index2);
                    IF (err)
                        error("error in toMixedBase");
                    for (d = 0; d < var_rank[i]; d++)
                        index2[d] = index[d] + index2[d] * stride[d];
                    value[j] = hash_$1(var_type[i], var_rank[i], index2,
                        NCT_ITYPE($1));
                    allInExtRange = allInExtRange
                        && inRange3(value[j], var_type[i], NCT_ITYPE($1));
                }
                if (var_rank[i] == 0 && i%2 == 0)
                    err = nc_put_varm_$1(ncid,i,NULL,NULL,NULL,NULL,value);
                else
                    err = nc_put_varm_$1(ncid,i,index,count,stride,imap,value);
                if (canConvert) {
                    if (allInExtRange) {
                        IF (err)
                            error("%s", nc_strerror(err));
                    } else {
                        IF (err != NC_ERANGE)
                            error("range error: status = %d", err);
                    }
                } else {
                    IF (nels > 0 && err != NC_ECHAR)
                        error("wrong type: status = %d", err);
		}
	    }
	}
    }

    err = nc_close(ncid);
    IF (err)
	error("nc_close: %s", nc_strerror(err));

    check_vars_$1(scratch);

    err = remove(scratch);
    IF (err)
        error("remove of %s failed", scratch);
}
')dnl

TEST_NC_PUT_VARM(text)
TEST_NC_PUT_VARM(uchar)
TEST_NC_PUT_VARM(schar)
TEST_NC_PUT_VARM(short)
TEST_NC_PUT_VARM(int)
TEST_NC_PUT_VARM(long)
TEST_NC_PUT_VARM(float)
TEST_NC_PUT_VARM(double)
TEST_NC_PUT_VARM(ushort)
TEST_NC_PUT_VARM(uint)
TEST_NC_PUT_VARM(longlong)
TEST_NC_PUT_VARM(ulonglong)


void
test_nc_put_att_text(void)
{
    int ncid;
    int i;
    int j;
    size_t k;
    int err;
    text value[MAX_NELS];

#ifdef TEST_PNETCDF
    err = nc_create_par(scratch, NC_NOCLOBBER|NC_PNETCDF, MPI_COMM_WORLD, MPI_INFO_NULL, &ncid);
#else
    err = nc_create(scratch, NC_NOCLOBBER, &ncid);
#endif
    IF (err) {
        error("nc_create: %s", nc_strerror(err));
        return;
    }
    def_dims(ncid);
    def_vars(ncid);

    {
	const char *const tval = "value for bad name";
	const size_t tval_len = strlen(tval);

	err = nc_put_att_text(ncid, 0, "", tval_len, tval);
	IF (err != NC_EBADNAME)
	   error("should be NC_EBADNAME: status = %d", err);
    }
    for (i = -1; i < numVars; i++) {
        for (j = 0; j < NATTS(i); j++) {
            if (ATT_TYPE(i,j) == NC_CHAR) {
		assert(ATT_LEN(i,j) <= MAX_NELS);
		err = nc_put_att_text(BAD_ID, i, ATT_NAME(i,j), ATT_LEN(i,j),
		    value);
		IF (err != NC_EBADID)
		    error("bad ncid: status = %d", err);
		err = nc_put_att_text(ncid, BAD_VARID, ATT_NAME(i,j),
		    ATT_LEN(i,j), value);
		IF (err != NC_ENOTVAR)
		    error("bad var id: status = %d", err);
		for (k = 0; k < ATT_LEN(i,j); k++) {
		    value[k] = hash(ATT_TYPE(i,j), -1, &k);
		}
		err = nc_put_att_text(ncid, i, ATT_NAME(i,j),
		    ATT_LEN(i,j), value);
		IF (err) {
		    error("%s", nc_strerror(err));
		}
	    }
        }
    }

    check_atts_text(ncid);
    err = nc_close(ncid);
    IF (err)
        error("nc_close: %s", nc_strerror(err));

    err = remove(scratch);
    IF (err)
        error("remove of %s failed", scratch);
}


dnl TEST_NC_PUT_ATT(TYPE)         numeric only
dnl
define(`TEST_NC_PUT_ATT',dnl
`dnl
void
test_nc_put_att_$1(void)
{
    int ncid;
    int i;
    int j;
    size_t k;
    int err;
    $1 value[MAX_NELS];
    int allInExtRange;  /* all values within external range? */

#ifdef TEST_PNETCDF
    err = nc_create_par(scratch, NC_NOCLOBBER|NC_PNETCDF, MPI_COMM_WORLD, MPI_INFO_NULL, &ncid);
#else
    err = nc_create(scratch, NC_NOCLOBBER, &ncid);
#endif
    IF (err) {
        error("nc_create: %s", nc_strerror(err));
        return;
    }
    def_dims(ncid);
    def_vars(ncid);

    for (i = -1; i < numVars; i++) {
        for (j = 0; j < NATTS(i); j++) {
            if (!(ATT_TYPE(i,j) == NC_CHAR)) {
		assert(ATT_LEN(i,j) <= MAX_NELS);
		err = nc_put_att_$1(BAD_ID, i, ATT_NAME(i,j), ATT_TYPE(i,j),
		    ATT_LEN(i,j), value);
		IF (err != NC_EBADID)
		    error("bad ncid: status = %d", err);
		err = nc_put_att_$1(ncid, BAD_VARID, ATT_NAME(i,j),
		    ATT_TYPE(i,j), ATT_LEN(i,j), value);
		IF (err != NC_ENOTVAR)
		    error("bad var id: status = %d", err);
		err = nc_put_att_$1(ncid, i, ATT_NAME(i,j), BAD_TYPE,
		    ATT_LEN(i,j), value);
		IF (err != NC_EBADTYPE)
		    error("bad type: status = %d", err);
		for (allInExtRange = 1, k = 0; k < ATT_LEN(i,j); k++) {
		    value[k] = hash_$1(ATT_TYPE(i,j), -1, &k, NCT_ITYPE($1));
		    allInExtRange = allInExtRange
			&& inRange3(value[k], ATT_TYPE(i,j), NCT_ITYPE($1));
		}
		err = nc_put_att_$1(ncid, i, ATT_NAME(i,j), ATT_TYPE(i,j),
		    ATT_LEN(i,j), value);
		if (allInExtRange) {
		    IF (err)
			error("%s", nc_strerror(err));
		} else {
                    IF (err != NC_ERANGE)
                        error("range error: status = %d", err);
		}
	    }
        }
    }

    check_atts_$1(ncid);
    err = nc_close(ncid);
    IF (err)
        error("nc_close: %s", nc_strerror(err));

    err = remove(scratch);
    IF (err)
        error("remove of %s failed", scratch);
}
')dnl

TEST_NC_PUT_ATT(uchar)
TEST_NC_PUT_ATT(schar)
TEST_NC_PUT_ATT(short)
TEST_NC_PUT_ATT(int)
TEST_NC_PUT_ATT(long)
TEST_NC_PUT_ATT(float)
TEST_NC_PUT_ATT(double)
TEST_NC_PUT_ATT(ushort)
TEST_NC_PUT_ATT(uint)
TEST_NC_PUT_ATT(longlong)
TEST_NC_PUT_ATT(ulonglong)
