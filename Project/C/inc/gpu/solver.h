#ifndef _SOLVER_H_
#define _SOVLER_H_

#include <cuda.h>
#include <cufft.h>
#include "const.h"

// Temp variables for RungeKutta4 function
double* k1;
double* k2;
double* k3;
double* k4;
double* tmp;
double* delsq;
double* c_gpu;

cufftDoubleComplex *cval;

cufftHandle rfft;
cufftHandle irfft;

dim3 grid, threads;

__global__ void deriv(double h, cufftDoubleComplex* cval);
__global__ void k12_sum(double* c, double* k, double* tmp, double dt);
__global__ void k3_sum(double* c, double* k, double* tmp, double dt);
__global__ void k_sum_tot(double* c, double* k1, double* k2, double* k3, double* k4, double dt);
__global__ void inside_deriv(double* c, double* delsq);

void RungeKutta4(double* c, double dt);
void f(double* c, double* dc);
void laplacian(double* c, double h, double* delsq);

void init_solver(double *c);
void free_solver();
void cudaGetSolution(double *c);

#endif
