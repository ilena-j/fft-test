`timescale 1ns / 1ps
// FFT Testbench
// This testbench simulates the behavior of the FFT IP core we're using for the trigger.
// The IP instantiated here is a 64-point FFT with Pipelined Streaming IO architecture.

// Test: drive S_AXIS_CONFIG_TDATA and S_AXIS_CONFIG_TVALID, look for S_AXIS_CONFIG_TREADY


module tb_fft;

parameter T_HOLD = 1; // hold TVALID and TDATA high for 1 ns after TREADY is asserted

// Configuration Channel Parameters
parameter [8:0] CONFIG_ZERO_PAD = 9'b0; // zero pad 
parameter [5:0] SCALE_SCHEDULE = 6'b101011; // conservative scale schedule
parameter FWD = 1'b1; // forward FFT

// I/O Ports
reg aclk = 1;
reg aclken = 1; // clock enable -- drive low to pause the core
reg aresetn = 1; // must be held low for 2 clks to reset

// CONFIG
reg [7:0] s_axis_config_tdata = 8'b0;
reg s_axis_config_tvalid = 1'b0;
wire s_axis_config_tready; // fft out out

// SLAVE AXIS DATA
reg [31:0] s_axis_data_tdata = 32'b0;
reg s_axis_data_tvalid = 1'b0;
wire s_axis_data_tready; // fft out
reg s_axis_data_tlast = 1'b0;

// MASTER AXIS DATA
wire [31:0] m_axis_data_tdata;
wire m_axis_data_tvalid;
reg m_axis_data_tready = 1'b0; // fft in
wire m_axis_data_tlast;

wire [15:0] m_axis_data_tuser; // xk_index?

// EVENTS (all fft out)
wire event_frame_started;
wire event_tlast_unexpected;
wire event_tlast_missing;
wire event_status_channel_halt;
wire event_data_in_channel_halt;
wire event_data_out_channel_halt;
wire event_fft_overflow;

// FFT Instance
xfft_2 your_instance_name (
  .aclk(aclk),                                                // input wire aclk
  .aresetn(aresetn),                                          // input wire aresetn
  .s_axis_config_tdata(s_axis_config_tdata),                  // input wire [7 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(s_axis_config_tvalid),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(s_axis_config_tready),                // output wire s_axis_config_tready
  .s_axis_data_tdata(s_axis_data_tdata),                      // input wire [31 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(s_axis_data_tvalid),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(s_axis_data_tready),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(s_axis_data_tlast),                      // input wire s_axis_data_tlast
  .m_axis_data_tdata(m_axis_data_tdata),                      // output wire [31 : 0] m_axis_data_tdata
  .m_axis_data_tuser(m_axis_data_tuser),                      // output wire [15 : 0] m_axis_data_tuser
  .m_axis_data_tvalid(m_axis_data_tvalid),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(m_axis_data_tready),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(m_axis_data_tlast),                      // output wire m_axis_data_tlast
  .m_axis_status_tdata(m_axis_status_tdata),                  // output wire [7 : 0] m_axis_status_tdata
  .m_axis_status_tvalid(m_axis_status_tvalid),                // output wire m_axis_status_tvalid
  .m_axis_status_tready(m_axis_status_tready),                // input wire m_axis_status_tready
  .event_frame_started(event_frame_started),                  // output wire event_frame_started
  .event_tlast_unexpected(event_tlast_unexpected),            // output wire event_tlast_unexpected
  .event_tlast_missing(event_tlast_missing),                  // output wire event_tlast_missing
  .event_fft_overflow(event_fft_overflow),                    // output wire event_fft_overflow
  .event_status_channel_halt(event_status_channel_halt),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(event_data_in_channel_halt),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt(event_data_out_channel_halt)  // output wire event_data_out_channel_halt
);


// Tasks ----------------------------------

// Send a sample of data according to AXI Stream protocol:
// set TVALID, wait until TREADY is set, then clear TVALID
task drive_sample;
    input reg [31:0]                data;
    input reg                       last;
    begin
        s_axis_data_tdata <= data;
        s_axis_data_tlast <= last;
        
        s_axis_data_tvalid <= 1;
        
        @(posedge aclk);
        while(s_axis_data_tready == 0 ) @(posedge aclk);
        #T_HOLD;
        s_axis_data_tvalid <= 0;
    end
 endtask

// send data into the FFT block until no more data is left
// calls the drive_sample task
task drive_frame;
   input integer N;
   input integer fp;
   reg sample_last;
   integer index;
   reg [15:0] x_re;
   reg [15:0] x_im; // we are using 0s for imaginary data
   begin
        
         index = 0;
         sample_last = 0;
         x_re = 16'b0;		  x_im = 16'b0;
       while(index < N)begin            
           
           $fscanf(fp, "%d\n",  x_re);			
           sample_last = (index == N - 1) ? 1 : 0;
           drive_sample({x_im, x_re}, sample_last);    
           index = index + 1;
       end
       
   end
endtask

// file pointers lol
integer fp_in, fp_out;

always #5 aclk = ~aclk;

initial begin

// reset
#10
aresetn = 0;
#20
aresetn = 1;

// drive S_AXIS_CONFIG_TDATA
s_axis_config_tdata = {SCALE_SCHEDULE, FWD};
s_axis_config_tvalid = 1'b1;
#10
while(s_axis_config_tready == 0 ) begin
    @(posedge aclk);
end
s_axis_config_tvalid = 1'b0;

// open files
fp_in  = $fopen("C:/Users/ilena/Documents/apr-private/fpga/fft-test/files-sim5/fft_input.txt", "r");
fp_out = $fopen("C:/Users/ilena/Documents/apr-private/fpga/fft-test/files-sim5/fft_out.txt", "w");

// send the data in
drive_frame(64, fp_in);
@(posedge aclk);
$fclose(fp_in);

m_axis_data_tready = 1'b1; // tell the FFT to keep outputting data

// wait for master tlast
@(posedge m_axis_data_tlast);
repeat(10)@(posedge aclk);    
$fclose(fp_out);              

end


always @(posedge aclk)
        if(m_axis_data_tvalid)begin
            $fwrite(fp_out, "%d \n", $signed(m_axis_data_tdata[15: 0]));
            $fwrite(fp_out, "%d \n", $signed(m_axis_data_tdata[31:16]));
        end 


endmodule
