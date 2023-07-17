# Trigger FFT Data Generation
# Generates a 30 kHz sine wave, scaled to integer values from 0 to 1023 centered at 512
# Sampled at 500 ks/sec 

import numpy as np
from matplotlib import pyplot as plt
from scipy.fft import fft, fftfreq

def bit_reverse(k):
    x = bin(k)
    x = x[2:len(x)]
    x = x[::-1]
    x = int(x, 2)
    return x

N = 64 # 64 point FFT
Fs = 446000/4 # decimate by 4 -- use 1 every 4 ADC samples

t_step = (1/Fs)
freq = 30000
t = np.arange(N)

prop_zeros=0.75

num_zeros =  int(prop_zeros * N)
num_data = N-num_zeros
raw_sine = 0.5 * np.sin(2*np.pi * freq * t * t_step ) + 0.5# generate sine wave
raw_sine = np.append(np.zeros(num_zeros) + 0.5,raw_sine[0:num_data])
data_floats = raw_sine*1023             # scale to between 0 and 1023
data = np.rint(data_floats)                           # round to nearest integer

# plot the input data
plt.subplot(311)
plt.plot(t*t_step, data)

# write input data to a file
with open("fft_input.txt", mode="wt") as f:
	for i in data:
		f.write(str(int(i)))
		f.write('\n')

# plot a SciPy FFT of the input data
scipy_fft = fft(data) ** 2
scipy_fft_freq = fftfreq(N, t_step)

plt.subplot(312)
plt.stem(scipy_fft_freq, scipy_fft)
plt.title('Scipy FFT')
plt.xlabel('Freq (Hz)')


# Plot the FFT from the testbench -----------------------------------------------------------------
# generate the frequency axis
k = np.arange(0, N)

# load in the data
sfft    = np.loadtxt('fft_out.txt')
#ufft    = sfft[0::2]**2 + sfft[1::2]**2     # real magnitude^2 + imaginary magnitude^2
                                            # real #s are in even indices, imaginary in odd
ufft = sfft[0::2]**2


real_order = np.zeros(64)
for i in range(0, 64) :
    real_order[bit_reverse(i)] = ufft[i] 

rtl_freq_axis = np.arange(0, Fs, Fs/N)

plt.subplot(313)
plt.stem(rtl_freq_axis[1:], real_order[1:])
#plt.plot(f_axis/1e6,10*np.log10(ufft/np.max(ufft)),'.-b')
#plt.plot(f_axis/1e6, SNR_signal, '.-r', label="Input SNR is {} dB".format(snr))
#plt.plot(f_axis/1e6, SNR_FFT, '.-k', label="FFT SNR is 10*log10({}) = {} dB".format(N, np.round(10*np.log10(N))))
#plt.legend(loc="upper right")
plt.title('FPGA FFT RTL Simulation')
plt.ylabel('dB ')
plt.xlabel('f, Hz')
plt.grid()
plt.show()