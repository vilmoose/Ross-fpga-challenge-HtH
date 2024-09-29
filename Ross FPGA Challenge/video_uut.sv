/****************************************************************************
FILENAME     :  video_uut.sv
PROJECT      :  Hack the Hill 2024
****************************************************************************/

/*  INSTANTIATION TEMPLATE  -------------------------------------------------

video_uut video_uut (       
    .clk_i          ( ),//               
    .cen_i          ( ),//
    .vid_sel_i      ( ),//
    .vdat_bars_i    ( ),//[19:0]
    .vdat_colour_i  ( ),//[19:0]
    .fvht_i         ( ),//[ 3:0]
    .fvht_o         ( ),//[ 3:0]
    .video_o        ( ) //[19:0]
);

-------------------------------------------------------------------------- */


module video_uut (
    input  wire         clk_i           ,// clock
    input  wire         cen_i           ,// clock enable
    input  wire         vid_sel_i       ,// select source video
    input  wire [19:0]  vdat_bars_i     ,// input video {luma, chroma}
    input  wire [19:0]  vdat_colour_i   ,// input video {luma, chroma}
    input  wire [3:0]   fvht_i          ,// input video timing signals
    output wire [3:0]   fvht_o          ,// 1 clk pulse after falling edge on input signal
    output wire [19:0]  video_o          // 1 clk pulse after any edge on input signal
); 

reg [19:0]  vid_d1;
reg [3:0]   fvht_d1;
reg [19:0] test_sig;
reg [19:0] bg_reg;


reg [15:0] x = 0; //x coordinate
reg [15:0] y = 0; //y coordinate

bit blanking = 0; // change to reg maybe

// temp - might be a signal for this
//parameter ver_lines = 1125;

parameter A = 10'h3fa;
parameter B = 10'h0c4;
assign test_sig = {A, B};

//white
parameter Y_white = 10'h2d1;
parameter CB_white = 10'h200;
parameter CR_white = 10'h200;

//yellow
parameter Y_yellow = 10'h2a2;
parameter CB_yellow = 10'h21f;
parameter CR_yellow = 10'h060;

//cyan
parameter Y_cyan = 10'h245;
parameter CB_cyan = 10'h0b0;
parameter CR_cyan = 10'h24d;

//green
parameter Y_green = 10'h216;
parameter CB_green = 10'h0cf;
parameter CR_green = 10'h0fd;

//purple
parameter Y_purple = 10'h0fb;
parameter CB_purple = 10'h331;
parameter CR_purple = 10'h303;

//red
parameter Y_red = 10'h0cc;
parameter CB_red = 10'h350;
parameter CR_red = 10'h1b3;

//blue
parameter Y_blue = 10'h06f;
parameter CB_blue = 10'he1;
parameter CR_blue = 10'h350;

//black
parameter Y_black = 10'h040;
parameter CB_black = 10'h200;
parameter CR_black = 10'h200;

//binary value to know if we are incrementing or decrementing
bit incX = 1;
bit incY = 1;

//speed to move at
logic[15:0] speed = 3;

//flag to flip between Y/CB and Y/CR
bit flip = 0;

//shape - x ranges
logic[15:0] shape_xMin = 750;
logic[15:0] shape_xMax = 1000;
logic[15:0] Rxmin = 750;
logic[15:0] Rxmax = 950;
logic[15:0] Oxmin = 1000;
logic[15:0] Oxmax = 1200;
logic[15:0] S1xmin = 1250;
logic[15:0] S1xmax = 1450;
logic[15:0] S2xmin = 1500;
logic[15:0] S2xmax = 1700;

//shape - y ranges
logic[15:0] shape_yMin = 450;
logic[15:0] shape_yMax = 700;

wire HSync = fvht_i[1];
wire VSync = fvht_i[2];


reg HDelay = 0;
wire HRise = HSync & ~HDelay;
wire HFall = ~HSync & HDelay;

reg VDelay = 0;
wire VRise = VSync & ~VDelay;
wire VFall = ~VSync & VDelay;

always @(posedge clk_i) begin
		
	if(cen_i) begin
		//check if blanking and set coordinate system to (0,0)
		//reset
		if((HSync | VSync)) begin
			blanking <= 1; //set blanking to 1 (true)
		end else begin
			blanking <= 0; //set blanking to 0 (false)
		end
		if (VFall) begin
			y <= 0; //new frame 
			
			//Movement in horizontal direction
			if(S2xmax >= 1919) begin
				incX = 0;
			end else if(Rxmin <= 0) begin
				incX = 1;
			end
			
			if(incX) begin
				Rxmin = Rxmin + speed;
				Rxmax = Rxmax + speed;
				Oxmin = Oxmin + speed;
				Oxmax = Oxmax + speed;
				S1xmin = S1xmin + speed;
				S1xmax = S1xmax + speed;
				S2xmin = S2xmin + speed;
				S2xmax = S2xmax + speed;
				
			end else begin
				Rxmin = Rxmin - speed;
				Rxmax = Rxmax - speed;
				Oxmin = Oxmin - speed;
				Oxmax = Oxmax - speed;
				S1xmin = S1xmin - speed;
				S1xmax = S1xmax - speed;
				S2xmin = S2xmin - speed;
				S2xmax = S2xmax - speed;
			end
			
			//Movement in verticaly direction
			if(shape_yMax >= 1080) begin
				incY = 0;
				
			end else if(shape_yMin <= 0) begin
				incY = 1;
			end
			
			if(incY) begin
				shape_yMin = shape_yMin + speed;
				shape_yMax = shape_yMax + speed;
				
			end else begin
				shape_yMin = shape_yMin - speed;
				shape_yMax = shape_yMax - speed;
			end
		end
		
		if (HFall) begin
			x <= 0;
			y <= y + 1;
		end

		//add box 
		if(!blanking) begin 
			if(((x > Rxmin) && (x < Rxmax) && (y > shape_yMin) && (y < shape_yMax)) || //R
				((x > Oxmin) && (x < Oxmax) && (y > shape_yMin) && (y < shape_yMax)) || //O
				((x > S1xmin) && (x < S1xmax) && (y > shape_yMin) && (y < shape_yMax)) ||  //S
				((x > S2xmin) && (x < S2xmax) && (y > shape_yMin) && (y < shape_yMax))  //S
			) begin 
				if(vid_sel_i) begin
					if(x >= 0 && x < 400) begin
						vid_d1 <= (flip) ? {10'h3ff, CR_blue} : {10'h3ff, CR_blue}; //Dark red
					end else if(x >= 400 && x < 800) begin
						vid_d1 <= (flip) ? {10'h2cc, CR_blue} : {10'h2cc, CR_blue}; //Slightly Brighter red
					end else if(x >= 800 && x < 1200) begin
						vid_d1 <= (flip) ? {10'h199, CR_blue} : {10'h199, CR_blue}; //Medium red
					end else if(x >= 1200 && x < 1600) begin
						vid_d1 <= (flip) ? {10'h0e6, CR_blue} : {10'h0e6, CR_blue}; //Brighter red
					end else if(x >= 1600) begin
						vid_d1 <= (flip) ? {10'h080, CR_blue} : {10'h080, CR_blue}; //Default red
					end
				end else begin 
					if(x >= 0 && x < 400) begin
						vid_d1 <= (flip) ? {10'h3ff, CB_red} : {10'h3ff, CR_red}; //Dark red
					end else if(x >= 400 && x < 800) begin
						vid_d1 <= (flip) ? {10'h2cc, CB_red} : {10'h2cc, CR_red}; //Slightly Brighter red
					end else if(x >= 800 && x < 1200) begin
						vid_d1 <= (flip) ? {10'h199, CB_red} : {10'h199, CR_red}; //Medium red
					end else if(x >= 1200 && x < 1600) begin
						vid_d1 <= (flip) ? {10'h0e6, CB_red} : {10'h0e6, CR_red}; //Brighter red
					end else if(x >= 1600) begin
						vid_d1 <= (flip) ? {10'h080, CB_red} : {10'h080, CR_red}; //Default red
					end
				end
			end else begin 
				vid_d1 <= (flip) ? {Y_black, CB_black} : {Y_black, CR_black};
			end
			
			//For rectangle loop of R
			if (((x > Rxmin + 60) && (x < Rxmax - 40) && (y > shape_yMin + 31) && (y < shape_yMax - 194)) || //Top R
				((x > Rxmin + 60) && (x < Rxmax - 100) && (y > shape_yMin + 94) && (y < shape_yMax)) || //Left R
				((x > Rxmin + 160) && (x < Rxmax) && (y > shape_yMin + 94) && (y < shape_yMax)) || //Right R
				((x > Oxmin + 50) && (x < Oxmax - 50) && (y > shape_yMin + 50) && (y < shape_yMax - 50)) || //Middle O
				((x > S1xmin + 50) && (x < S1xmax) && (y > shape_yMin + 50) && (y < shape_yMax - 150)) || //Top S1
				((x > S1xmin) && (x < S1xmax - 50) && (y > shape_yMin + 150) && (y < shape_yMax - 50)) || //Bottom S1
				((x > S2xmin + 50) && (x < S2xmax) && (y > shape_yMin + 50) && (y < shape_yMax - 150)) || //Top S2
				((x > S2xmin) && (x < S2xmax - 50) && (y > shape_yMin + 150) && (y < shape_yMax - 50)) //Bottom S2
				) 
			begin
				vid_d1 <= (flip) ? {Y_black, CB_black} : {Y_black, CR_black};
			end
			x <= x + 1;		
		end
		 
		 flip <= ~flip;
		 HDelay <= HSync;
	    VDelay <= VSync;
       fvht_d1 <= fvht_i;
    end
end

// OUTPUT
assign fvht_o  = fvht_d1;
assign video_o = vid_d1;

endmodule

