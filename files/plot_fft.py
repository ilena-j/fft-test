# script to plot FFT output, which is generated by the RTL sim and stored in fft_out.txt
from matplotlib import pyplot as plt
import numpy as np 
from scipy.fft import fft, fftfreq

# Plot the input data -----------------------------------------------------------------------------
N = 128
Fs = 446000
t_step = (1/Fs)
freq = 30000
t = np.arange(N)
time_axis = t * t_step 

raw_sine = 0.5 * np.cos(2*np.pi * freq * t * t_step ) # generate sine wave
bias = np.ones(N) * 0.5                             # generate 0.5 bias
data_floats = np.add(bias, raw_sine)*1023             # scale to between 0 and 1023
data = np.rint(data_floats)                           # round to nearest integer

plt.subplot(311)
plt.title('Input Data')
plt.xlabel('Time')
plt.plot(time_axis, data)

# Plot the Scipy FFT of the data ------------------------------------------------------------------
scipy_fft = fft(data) ** 2
scipy_fft_freq = fftfreq(N, t_step)

plt.subplot(312)
plt.stem(scipy_fft_freq, scipy_fft)
plt.title('Scipy FFT')
plt.xlabel('Freq (Hz)')

# Plot the FFT from the testbench -----------------------------------------------------------------

# generate the frequency axis
k = np.arange(0, N)
f_axis = (k*Fs)/N

# load in the data
sfft    = np.loadtxt('fft_out.txt')
ufft    = sfft[0::2]**2 + sfft[1::2]**2     # real magnitude^2 + imaginary magnitude^2
                                            # real #s are in even indices, imaginary in odd

plt.subplot(313)
plt.plot(scipy_fft_freq, ufft)
#plt.plot(f_axis/1e6,10*np.log10(ufft/np.max(ufft)),'.-b')
#plt.plot(f_axis/1e6, SNR_signal, '.-r', label="Input SNR is {} dB".format(snr))
#plt.plot(f_axis/1e6, SNR_FFT, '.-k', label="FFT SNR is 10*log10({}) = {} dB".format(N, np.round(10*np.log10(N))))
#plt.legend(loc="upper right")
plt.title('FPGA FFT RTL Simulation')
plt.ylabel('dB ')
plt.xlabel('f, Hz')
plt.grid()
plt.show()