SUBDIR+=	lib/freebsd

check:
	@cd tests; kyua test

.include <bsd.subdir.mk>
