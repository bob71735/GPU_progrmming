#include <cstdio>
#include <cstdlib>
#include <stdio.h>
#include <math.h> 
#include "SyncedMemory.h"
#include <ctype.h>

#define CHECK {\
	auto e = cudaDeviceSynchronize();\
	if (e != cudaSuccess) {\
		printf("At " __FILE__ ":%d, %s\n", __LINE__, cudaGetErrorString(e));\
		abort();\
	}\
}
__global__ void SomeTransform(char *input_gpu, int fsize) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	int num = int(ceil(fsize / 64.0));
	if (idx < fsize && input_gpu[idx] != '\n') {
		int finish = idx==63?fsize:(idx+1)*num;
		for(int i = idx*num; i < finish; ++i){
			char c = input_gpu[i];
			if (c >= 'a' && c <= 'z'){
				c -= 32;
				input_gpu[i] = c;
			}
		}
	}
}
int main(int argc, char **argv)
{
	// init, and check
	if (argc != 2) {
		printf("Usage %s <input text file>\n", argv[0]);
		abort();
	}
	FILE *fp = fopen(argv[1], "r");
	if (!fp) {
		printf("Cannot open %s", argv[1]);
		abort();
	}
	// get file size
	fseek(fp, 0, SEEK_END);
	size_t fsize = ftell(fp);
	fseek(fp, 0, SEEK_SET);

	// read files
	MemoryBuffer<char> text(fsize+1);
	auto text_smem = text.CreateSync(fsize);
	CHECK;
	fread(text_smem.get_cpu_wo(), 1, fsize, fp);
	text_smem.get_cpu_wo()[fsize] = '\0';
	fclose(fp);

	// TODO: do your transform here
	char *input_gpu = text_smem.get_gpu_rw();
	// An example: transform the first 64 characters to '!'
	// Don't transform over the tail
	// And don't transform the line breaks
	SomeTransform <<< 2, 32 >>>(input_gpu, fsize);
	//printf("%d\n",fsize);
	puts(text_smem.get_cpu_ro());
	return 0;
}
