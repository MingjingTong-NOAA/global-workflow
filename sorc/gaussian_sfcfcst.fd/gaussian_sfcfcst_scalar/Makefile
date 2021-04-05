SHELL=	/bin/sh

CMD= gaussian_sfcfcst_scalar_intrp.exe

OBJS = gaussian_sfcfcst_scalar_intrp.o

build: $(CMD)

$(CMD):	$(OBJS)
	$(FCOMP) $(FFLAGS) -I$(NEMSIO_INC) $(NETCDF_INCLUDE) -o $(CMD) $(OBJS) $(NETCDF_LDFLAGS_F) $(NEMSIO_LIB) $(BACIO_LIB4) $(W3NCO_LIBd) $(SP_LIB4)

gaussian_sfcfcst_scalar_intrp.o:  gaussian_sfcfcst_scalar_intrp.f90
	$(FCOMP) $(FFLAGS) -I$(NEMSIO_INC) $(NETCDF_INCLUDE) -c gaussian_sfcfcst_scalar_intrp.f90

install:
	cp ${CMD} ../../../exec

clean:
	rm -f *.o *.mod ${CMD} ../../../exec/${CMD}

test:
	@echo NO TESTS YET
