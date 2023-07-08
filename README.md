# FFT Test
Contains testbenches for the Xilinx FFT IP core.

*Note: File paths in the testbench files (`fft-test.srcs/sim_2/new/tb_fft.v` and `fft-test.srcs/sim_3/new/fft_ripoff_tb.v`) are absolute. You will need to change them. I'm looking for a better way to do this.*

##### ip core
The IP core is a 128-point FFT core using Pipelined Streaming I/O architecture. Documentation for the core can be found here: [Product Guide 109](https://docs.xilinx.com/r/en-US/pg109-xfft/Fast-Fourier-Transform-v9.1-LogiCORE-IP-Product-Guide) 

##### sim_2
Contains the testbench we've been working with thus far. Input/output data & relevant scripts are located in the "Files" directory.

##### sim_3
Contains the testbench, using the same IP core as sim_2, as GitHub user Farbius. YouTube video [here](https://www.youtube.com/watch?v=HKeaBs_3V04&t=304s), GitHub [here](https://github.com/farbius/dsp_xilinx_ip/blob/main/rtl_tb/fft_tb.v)