/*  FFT Testbench ripped directly from https://github.com/farbius/dsp_xilinx_ip/blob/main/rtl_tb/fft_tb.v
 *  Only changes are file names, and s_axis_config_tdata:
 *  our FFT core doesn't have a runtime configurable size, so I've fixed it at 128 points
 */

`timescale 1ns / 1ps

module fft_tb();

parameter       CLOCK_PERIOD    = 10;
parameter       T_HOLD    = 1;

// FFT I/O ----------------------------------------------------------------------------------------
reg             aresetn = 0; // FFT's active low reset
reg             aclk    = 0; // clock

reg 			s_axis_config_tvalid = 0; // Configuration Channel
reg [15:0]      s_axis_config_tdata = 0;
wire 			s_axis_config_tready;

reg  [31 : 0]   s_axis_data_tdata = 0;  // Data Input Channel
reg     		s_axis_data_tvalid = 0;
wire     		s_axis_data_tready;
reg    			s_axis_data_tlast = 0;

wire [31 : 0] 	m_axis_data_tdata;      // Data Output Channel
wire    		m_axis_data_tvalid;
reg    			m_axis_data_tready = 1;
wire    		m_axis_data_tlast = 0;

wire 			event_frame_started;    // Status Signals
wire    		event_tlast_unexpected;
wire    		event_tlast_missing;
wire    		event_status_channel_halt;
wire    		event_data_in_channel_halt;
wire    		event_data_out_channel_halt;

// INPUT FILES
integer         fp_in   = 0; // input file
integer         fp_out  = 0; // output file

always
    #(CLOCK_PERIOD/2) aclk = ~aclk;
    
// RESET LOGIC ------------------------------------------------------------------------------------   
event reset_start;
event reset_done;

always // reset
begin
aresetn <= 1;
@(reset_start);
$display("<-- Reset");
    aresetn <= 0;
    repeat(10)@(posedge aclk);
    aresetn <= 1;
-> reset_done;
$display("<-- Reset done");
end

// CONFIGURATION CHANNEL --------------------------------------------------------------------------
// The configuration channel sets the scaling schedule & whether to do a forward or inverse FFT. 
// We write the settings we want into s_axis_config_tdata (16 bits), and then do an AXI Stream handshake.
// See the Google Drive document, "customizing & instantiating the FFT IP core" for more info
reg [6:0] ZERO_PAD = 7'b0; // zero padding
reg [7:0] SCALE_SCHEDULE = 8'b01101011; // scale schedule
parameter FWD = 1'b1; // forward FFT
parameter INV = 1'b0; // inverse FFT


// DRIVE INPUT DATA -------------------------------------------------------------------------------
// Task to drive 1 sample of data into the FFT. Performs the AXI Stream handshake.
task drive_sample;
    input reg [31:0]                data;
    input reg                       last;
    input integer                   valid_mode; // always 0 for us
    begin
        s_axis_data_tdata <= data;
        s_axis_data_tlast <= last;
        
        if (valid_mode == 1) begin // not using 
            s_axis_data_tvalid <= 0;
            repeat(1 + $urandom%4)@(posedge aclk);
            s_axis_data_tvalid <= 1;
        
        end 
        else begin
            s_axis_data_tvalid <= 1;
        end
        
        @(posedge aclk);
        while(s_axis_data_tready == 0 ) @(posedge aclk); // don't continue until the FFT is ready
        #T_HOLD;
        s_axis_data_tvalid <= 0;
    end
 endtask
    

// Task to drive 128 samples of data into the FFT. Reads data in from file & calls drive_sample
 task drive_frame;
    input integer N; // 128
    input integer valid_mode; // always 0
    input integer fp; // input file

    reg sample_last;
    integer idx; // index -- 0 to 127
    reg [15:0] x_re, x_im; // real and imaginary data: in the input file, real data is on even lines & imag data on odd lines
    begin
         
          idx = 0;
          sample_last = 0;
          x_re = 32'd0;
		  x_im = 32'd0;
        while(idx < N)begin            
            
            $fscanf(fp, " %d\n",  x_re);
			$fscanf(fp, " %d\n",  x_im);			
            sample_last = (idx == N - 1) ? 1 : 0; // assert s_axis_data_tlast when it's the last sample
            drive_sample({x_im, x_re}, sample_last, valid_mode);    
            idx = idx + 1;
        end
        
    end
 endtask 

// INITIAL BEGIN ----------------------------------------------------------------------------------
initial begin

$display("<-- Start simulation");
repeat(10)@(posedge aclk);

-> reset_start; // Reset
@(reset_done);

@(posedge aclk);
repeat(10)@(posedge aclk);

$display("<-- Start FFT 128 points");

// Configure the FFT: Do an AXI Stream handshake
s_axis_config_tdata  = {ZERO_PAD, SCALE_SCHEDULE, FWD}; // at this point, TVALID is low
@ (posedge aclk);
s_axis_config_tvalid = 1; // assert TVALID
while(s_axis_config_tready == 0 ) begin // wait for the FFT to assert TREADY. 
    @(posedge aclk);                    // When both TVALID and TREADY are high, the FFT will
end                                     // take in whatever data is on that channel's TDATA line.
@(posedge aclk);                        
s_axis_config_tvalid = 0;               // After TREADY goes high, you can de-assert TVALID and TDATA

// Open files
fp_in  = $fopen("C:/Users/ilena/Documents/apr-private/fpga/fft-test/files-ripoff/fft_input.txt", "r");
fp_out = $fopen("C:/Users/ilena/Documents/apr-private/fpga/fft-test/files-ripoff/fft_out.txt", "w");

// Drive the input data
drive_frame(128, 0, fp_in);
@(posedge aclk);
$fclose(fp_in);
// wait for master tlast
@(posedge m_axis_data_tlast);
repeat(10)@(posedge aclk);
$fclose(fp_out);

$display("<-- Start Inverse FFT 512 points");
fp_in = $fopen("C:/Users/ilena/Documents/apr-private/fpga/fft-test/files-ripoff/fft_out.txt", "r"); // feed the forward FFT output back in
fp_out = $fopen("C:/Users/ilena/Documents/apr-private/fpga/fft-test/files-ripoff/ifft_out.txt", "w");

// Configure the FFT Core to do an inverse FFT
s_axis_config_tdata  = {ZERO_PAD, SCALE_SCHEDULE, INV}; // at this point, TVALID is low
@ (posedge aclk);
s_axis_config_tvalid = 1; // assert TVALID
while(s_axis_config_tready == 0 ) begin // wait for the FFT to assert TREADY. 
    @(posedge aclk);                    // When both TVALID and TREADY are high, the FFT will
end                                     // take in whatever data is on that channel's TDATA line.
@(posedge aclk);                        
s_axis_config_tvalid = 0;               // After TREADY goes high, you can de-assert TVALID and TDATA

// Drive the input data
drive_frame(128, 0, fp_in);
@(posedge aclk);
$fclose(fp_in);
// wait for master tlast
@(posedge m_axis_data_tlast);
repeat(10)@(posedge aclk);
$fclose(fp_out);


$display("<-- Simulation done !");
$finish;
end // initial begin

// Write the FFT output into a file
always @(posedge aclk)
        if(m_axis_data_tvalid)begin
            $fwrite(fp_out, "%d \n", $signed(m_axis_data_tdata[15: 0]));
            $fwrite(fp_out, "%d \n", $signed(m_axis_data_tdata[31:16]));
        end 
   

// FFT INSTANTIATION ------------------------------------------------------------------------------
xfft_0 dut_0
(
    .aclk (aclk),
    .aclken(1'b1),
    .aresetn(aresetn),
	
	.s_axis_config_tdata(s_axis_config_tdata),
    .s_axis_config_tvalid(s_axis_config_tvalid),
    .s_axis_config_tready(s_axis_config_tready),
	
    
    .s_axis_data_tvalid(s_axis_data_tvalid),
    .s_axis_data_tdata(s_axis_data_tdata),
	.s_axis_data_tready(s_axis_data_tready),
	.s_axis_data_tlast(s_axis_data_tlast),
    
    .m_axis_data_tdata(m_axis_data_tdata),
    .m_axis_data_tvalid(m_axis_data_tvalid),
    .m_axis_data_tready(m_axis_data_tready),
    .m_axis_data_tlast(m_axis_data_tlast),
	
	.event_frame_started(event_frame_started),
    .event_tlast_unexpected(event_tlast_unexpected),
    .event_tlast_missing(event_tlast_missing),
    .event_status_channel_halt(event_status_channel_halt),
    .event_data_in_channel_halt(event_data_in_channel_halt),
    .event_data_out_channel_halt(event_data_out_channel_halt)
	
	
);

   

endmodule
