cimport Grid
cimport ReferenceState
cimport PrognosticVariables
cimport DiagnosticVariables
cimport Kinematics
cimport ParallelMPI

import numpy as np
cimport numpy as np

import cython

from FluxDivergence cimport momentum_flux_divergence

cdef extern from 'momentum_diffusion.h':
    cdef void compute_diffusive_flux(Grid.DimStruct *dims, double* vgrad1, double* vgrad2, double* viscosity, double* flux)
    cdef void compute_entropy_source(Grid.DimStruct *dims, double* viscosity, double* strain_rate_mag, double* temperature, double* entropy_tendency)

cdef class MomentumDiffusion:

    def __init__(self, DiagnosticVariables.DiagnosticVariables DV,ParallelMPI.ParallelMPI Pa):
        DV.add_variables('viscosity','--','sym',Pa)
        return

    cpdef initialize(self, Grid.Grid Gr, PrognosticVariables.PrognosticVariables PV,
                     DiagnosticVariables.DiagnosticVariables DV, ParallelMPI.ParallelMPI Pa):

        self.flux = np.zeros((Gr.dims.dims*Gr.dims.npg*Gr.dims.dims,),dtype=np.double,order='c')

        return

    cpdef update(self, Grid.Grid Gr,ReferenceState.ReferenceState Rs, PrognosticVariables.PrognosticVariables PV,
                 DiagnosticVariables.DiagnosticVariables DV, Kinematics.Kinematics Ke):

        cdef:
            long i1
            long i2
            long shift_v1
            long shift_vgrad1
            long shift_vgrad2
            long shift_flux
            long count = 0
            long visc_shift = DV.get_varshift(Gr,'viscosity')
            long temp_shift = DV.get_varshift(Gr,'temperature')
            long s_shift = PV.get_varshift(Gr,'s')

        for i1 in xrange(Gr.dims.dims):
            shift_v1 = PV.velocity_directions[i1] * Gr.dims.npg
            for i2 in xrange(Gr.dims.dims):
                shift_vgrad1 = Ke.get_grad_shift(Gr,i1,i2)
                shift_vgrad2 = Ke.get_grad_shift(Gr,i1,i2)
                shift_flux = count * Gr.dims.npg

                #First we compute the flux
                compute_diffusive_flux(&Gr.dims,&Ke.vgrad[shift_vgrad1],&Ke.vgrad[shift_vgrad2],&DV.values[visc_shift],&self.flux[shift_flux])
                momentum_flux_divergence(&Gr.dims,&Rs.alpha0[0],&Rs.alpha0_half[0],&self.flux[shift_flux],&PV.values[shift_v1],Gr.dims.dx[i1],i1,i2)


                count += 1

        compute_entropy_source(&Gr.dims, &DV.values[visc_shift], &Ke.strain_rate_mag[0], &DV.values[temp_shift],&PV.tendencies[s_shift])






        return