/*
 * Copyright (c) Mark Johnston <markj@FreeBSD.org>
 */

#include <sys/sysctl.h>

#include <errno.h>
#include <stdlib.h>
#include <string.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

int	luaopen_sys_sysctl(lua_State *L);

static int
fmtval(lua_State *L, int *oidp, size_t oidlen, char *buf,
    size_t buflen __unused)
{
	int fmtbuf[128];
	int oid[CTL_MAXNAME + 2];
	size_t fmtlen;
	unsigned int ctltype;
	int error;

	memcpy(oid + 2, oidp, oidlen * sizeof(int));

	oid[0] = CTL_SYSCTL;
	oid[1] = CTL_SYSCTL_OIDFMT;
	fmtlen = sizeof(fmtbuf);
	error = sysctl(oid, oidlen + 2, fmtbuf, &fmtlen, NULL, 0);
	if (error != 0)
		return (luaL_error(L, "failed to resolve OIDFMT"));
	ctltype = *fmtbuf & CTLTYPE;

	switch (ctltype) {
	case CTLTYPE_STRING:
		/* XXX-MJ make sure it's really nul-terminated? */
		lua_pushstring(L, buf);
		break;
	default:
		lua_pushnil(L);
		break;
	}

	return (1);
}

static int
l_sysctl(lua_State *L)
{
	int oid[CTL_MAXNAME];
	char *oldp;
	size_t oldlen;
	unsigned int oidlen;
	int error;

	luaL_argcheck(L, lua_type(L, 1) == LUA_TTABLE, 1,
	    "bad argument type, expected an array");

	lua_pushnil(L);
	for (oidlen = 0; lua_next(L, 1) != 0; oidlen++)
		lua_pop(L, 1);
	if (oidlen > CTL_MAXNAME) {
		lua_pushnil(L);
		lua_pushstring(L, "sysctl OID is longer than CTLMAXNAME");
		return (2);
	}
	lua_pushnil(L);
	for (int i = 0; lua_next(L, 1) != 0; i++) {
		oid[i] = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}

	oldlen = 0;
	error = sysctl(oid, oidlen, NULL, &oldlen, NULL, 0);
	if (error != 0) {
		error = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(error));
		return (2);
	}
	oldlen *= 2; /* what sysctl(8) does */
	oldp = malloc(oldlen);
	if (oldp == NULL)
		return (luaL_error(L, "malloc: %s", strerror(errno)));
	error = sysctl(oid, oidlen, oldp, &oldlen, NULL, 0);
	if (error != 0) {
		error = errno;
		free(oldp);
		lua_pushnil(L);
		lua_pushstring(L, strerror(error));
		return (2);
	}

	return (fmtval(L, oid, oidlen, oldp, oldlen));
}

static int
l_sysctlbyname(lua_State *L)
{
	int oid[CTL_MAXNAME];
	const char *name;
	char *oldp;
	size_t oidlen, oldlen;
	int error;

	luaL_argcheck(L, lua_type(L, 1) == LUA_TSTRING, 1,
	    "bad argument type, expected a string");

	name = lua_tostring(L, 1);

	oldlen = 0;
	error = sysctlbyname(name, NULL, &oldlen, NULL, 0);
	if (error != 0) {
		error = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(error));
		return (2);
	}
	oldlen *= 2; /* what sysctl(8) does */
	oldp = malloc(oldlen);
	if (oldp == NULL)
		return (luaL_error(L, "malloc: %s", strerror(errno)));
	error = sysctlbyname(name, oldp, &oldlen, NULL, 0);
	if (error != 0) {
		error = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(error));
		return (2);
	}

	oidlen = sizeof(oid) / sizeof(oid[0]);
	error = sysctlnametomib(name, oid, &oidlen);
	error = sysctlbyname(name, oldp, &oldlen, NULL, 0);
	if (error != 0) {
		error = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(error));
		return (2);
	}

	return (fmtval(L, oid, oidlen, oldp, oldlen));
}

static const struct luaL_Reg l_sysctltab[] = {
	{"sysctl", l_sysctl},
	{"sysctlbyname", l_sysctlbyname},
	{NULL, NULL},
};

int
luaopen_sys_sysctl(lua_State *L)
{
	lua_newtable(L);

	luaL_setfuncs(L, l_sysctltab, 0);

	return (1);
}
