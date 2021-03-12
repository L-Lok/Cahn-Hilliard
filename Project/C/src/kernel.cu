extern "C" {
    #include "kernel.h"
    #include "functions.h"
}

#define REAL 0
#define CPLX 1


void cufft_laplacian(double* c, double h, double* delsq) {

    cufftExecD2Z(rfft, c, cval);

    grid.x=8;
    grid.y=13;
    grid.z=1;
    threads.x=16;
    threads.y=5;
    threads.z=1;

    deriv<<<grid, threads>>>(h, cval);

    cufftExecZ2D(irfft, cval, delsq);
}

void init_cuda() {
    size_t mem_size = N_DISCR*N_DISCR*sizeof(double);
    size_t complex_size = N_DISCR*N_DISCR*sizeof(cufftDoubleComplex);

    cudaMalloc((void **) &cval, complex_size);
    cudaMalloc((void **) &c_gpu, mem_size);

    cudaMalloc((void **) &k1, mem_size);
    cudaMalloc((void **) &k2, mem_size);
    cudaMalloc((void **) &k3, mem_size);
    cudaMalloc((void **) &k4, mem_size);

    cudaMalloc((void **) &tmp, mem_size);
    cudaMalloc((void **) &delsq, mem_size);

    cufftPlan2d(&rfft, N_DISCR, N_DISCR, CUFFT_D2Z);
    cufftPlan2d(&irfft, N_DISCR, N_DISCR, CUFFT_Z2D);
}

__global__ void deriv(double h, cufftDoubleComplex* cval) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;

    int l, ind;
    double k;
    double factor = 4.0*M_PI*M_PI*h*h;
    // Wavenumber
    l = (i < N_DISCR/2) ? i : i-N_DISCR;
    k = -factor * (j*j + l*l);

    // Multiply by (ik)²
    ind = i*(N_DISCR/2+1)+j;
    cval[ind].x = k*cval[ind].x;
    cval[ind].y = k*cval[ind].y;
}

__global__ void k12_sum(double* c, double* k, double* tmp, double dt) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    tmp[i] = c[i] + dt*k[i]/2.0;
}

__global__ void k3_sum(double* c, double* k, double* tmp, double dt) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    tmp[i] = c[i] + dt*k[i];
}
__global__ void k_sum_tot(double* c, double* k1, double* k2, double* k3, double* k4, double dt) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    c[i] += dt*(k1[i] + 2*k2[i] + 2*k3[i] + k4[i])/6.0;
}
__global__ void inside_deriv(double* c, double* delsq) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    delsq[i] = c[i]*c[i]*c[i] - c[i] - A*A*delsq[i];
}

int Nblocks = (N_DISCR*N_DISCR)/256;
int Nthreads = 256;


/*
 *  Compute one iteration of Runge Kutta 4
 *  Return value is done in-place.
 */
void RungeKutta4(double* c, double dt){

    size_t mem_size = N_DISCR*N_DISCR*sizeof(double);
    cudaMemcpy( c_gpu, c, mem_size, cudaMemcpyHostToDevice );


    // K1
    f(c_gpu, k1);

    // K2
    k12_sum<<<Nblocks, Nthreads>>>(c_gpu, k1, tmp, dt);
    f(tmp, k2);

    // K3
    k12_sum<<<Nblocks, Nthreads>>>(c_gpu, k2, tmp, dt);
    f(tmp, k3);

    // K4
    k3_sum<<<Nblocks, Nthreads>>>(c_gpu, k3, tmp, dt);
    f(tmp, k4);

    // C_i+1
    k_sum_tot<<<Nblocks, Nthreads>>>(c_gpu, k1, k2, k3, k4, dt);

    cudaMemcpy( c, c_gpu, mem_size, cudaMemcpyDeviceToHost );
}

/*
 *  Compute the time derivative of c
 *  Return value is not in-place.
 */
void f(double* c, double* dc) {

    cufft_laplacian(c, 1.0/N_DISCR, delsq);
    inside_deriv<<<Nblocks, Nthreads>>>(c, delsq);
    cufft_laplacian(delsq, 1.0/N_DISCR, dc);
}

// void copy_cuda_H2D(double* c_gpu, double* c){
//   size_t mem_size = N_DISCR*N_DISCR*sizeof(double);
//   cudaMemcpy( c_gpu, c, mem_size, cudaMemcpyHostToDevice );
// }
//
// void copy_cuda_D2H(double* c, double* c_gpu){
//   size_t mem_size = N_DISCR*N_DISCR*sizeof(double);
//   cudaMemcpy( c, c_gpu, mem_size, cudaMemcpyDeviceToHost );
// }






void free_cuda() {
    cudaFree(delsq);
    cudaFree(tmp);
    cudaFree(k1);
    cudaFree(k2);
    cudaFree(k3);
    cudaFree(k4);
    cudaFree(cval);
    cudaFree(c_gpu);
}
