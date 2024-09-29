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
    input  wire         vid_sel_color_i ,// select color
	 input  wire			vid_split_i		 ,// split characters
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

parameter X_COORD_MAX = 1920;
parameter Y_COORD_MAX = 1080;

parameter RX_MIN_START = 600;
parameter RY_MIN_START = 450;
parameter OX_MIN_START = 850;
parameter OY_MIN_START = 450;
parameter S1X_MIN_START = 1100;
parameter S1Y_MIN_START = 450;
parameter S2X_MIN_START = 1350;
parameter S2Y_MIN_START = 450;

bit current_split = 0;

bit blanking = 0;

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
parameter CB_blue = 10'h1e1;
parameter CR_blue = 10'h350;

//black
parameter Y_black = 10'h040;
parameter CB_black = 10'h200;
parameter CR_black = 10'h200;

//binary value to know if we are incrementing or decrementing
//when vid_split_i == 0
bit incX = 1;
bit incY = 1;
//when vid_split_i == 1
bit incRx = 0;
bit incRy = 1;
bit incOx = 0;
bit incOy = 0;
bit incS1x = 1;
bit incS1y = 0;
bit incS2x = 1;
bit incS2y = 1;

//speed to move at
logic[15:0] speed = 3;

//flag to flip between Y/CB and Y/CR
bit flip = 0;

//shape - x ranges
integer Rxmin = 750;
integer Rxmax = 950;
integer Oxmin = 1000;
integer Oxmax = 1200;
integer S1xmin = 1250;
integer S1xmax = 1450;
integer S2xmin = 1500;
integer S2xmax = 1700;

//shape - y ranges
integer shape_yMin = 450;
integer shape_yMax = 700;
integer Rymin = 450;
integer Rymax = 700;
integer Oymin = 450;
integer Oymax = 700;
integer S1ymin = 450;
integer S1ymax = 700;
integer S2ymin = 450;
integer S2ymax = 700;

// syncing signals
wire HSync = fvht_i[1];
wire VSync = fvht_i[2];

// rising and falling edges of HSync
reg HDelay = 0;
wire HRise = HSync & ~HDelay;
wire HFall = ~HSync & HDelay;

// rising and falling edges of VSync
reg VDelay = 0;
wire VRise = VSync & ~VDelay;
wire VFall = ~VSync & VDelay;

always @(posedge clk_i) begin
		
	if(cen_i) begin
		/* -- COORDINATE SYSTEM --
				Access *visible* pixels from (0,0) -> (1920, 1080)
		*/
		
		//check if in blanking region
		if((HSync | VSync)) begin
			blanking <= 1; //set blanking to 1 (true)
		end else begin
			blanking <= 0; //set blanking to 0 (false)
		end
		
		//VSync: new frame 
		if (VFall) begin
			y <= 0;
		end
		
		//HSync
		if (HFall) begin
			x <= 0;
			y <= y + 1;
		end
		
		if (!blanking) begin
			x <= x + 1;
		end
		
		
		/* -- DRAWING SHAPES */
		//Draw box around shape
		if(!blanking) begin 
			if(((x > Rxmin) && (x < Rxmax) && (y > Rymin) && (y < Rymax)) || //R
				((x > Oxmin) && (x < Oxmax) && (y > Oymin) && (y < Oymax)) || //O
				((x > S1xmin) && (x < S1xmax) && (y > S1ymin) && (y < S1ymax)) ||  //S
				((x > S2xmin) && (x < S2xmax) && (y > S2ymin) && (y < S2ymax))  //S
			) begin 
				// Select color of shape w/ probe[0]
				// BLUE
				if(vid_sel_color_i) begin
					if(x >= 0 && x < 400) begin
						vid_d1 <= (flip) ? {10'h3ff, CR_blue} : {10'h3ff, CB_blue}; //Brightest
					end else if(x >= 400 && x < 800) begin
						vid_d1 <= (flip) ? {10'h2cc, CR_blue} : {10'h2cc, CB_blue}; //Bright
					end else if(x >= 800 && x < 1200) begin
						vid_d1 <= (flip) ? {10'h199, CR_blue} : {10'h199, CB_blue}; //Medium
					end else if(x >= 1200 && x < 1600) begin
						vid_d1 <= (flip) ? {10'h0e6, CR_blue} : {10'h0e6, CB_blue}; //Dark
					end else if(x >= 1600) begin
						vid_d1 <= (flip) ? {10'h080, CR_blue} : {10'h080, CB_blue}; //Darkest
					end
				// RED
				end else begin 
					if(x >= 0 && x < 400) begin
						vid_d1 <= (flip) ? {10'h3ff, CR_red} : {10'h3ff, CB_red}; //Brightest
					end else if(x >= 400 && x < 800) begin
						vid_d1 <= (flip) ? {10'h2cc, CR_red} : {10'h2cc, CB_red}; //Bright
					end else if(x >= 800 && x < 1200) begin
						vid_d1 <= (flip) ? {10'h199, CR_red} : {10'h199, CB_red}; //Medium
					end else if(x >= 1200 && x < 1600) begin
						vid_d1 <= (flip) ? {10'h0e6, CR_red} : {10'h0e6, CB_red}; //Dark
					end else if(x >= 1600) begin
						vid_d1 <= (flip) ? {10'h080, CR_red} : {10'h080, CB_red}; //Darkest
					end
				end
			end else begin
				// Black background
				vid_d1 <= (flip) ? {Y_black, CB_black} : {Y_black, CR_black};
			end
			
			//Complete the shapes
			if (((x > Rxmin + 60) && (x < Rxmax - 40) && (y > Rymin + 31) && (y < Rymax - 194)) || //Top of R
				((x > Rxmin + 60) && (x < Rxmax - 100) && (y > Rymin + 94) && (y < Rymax)) || //Left of R
				((x > Rxmin + 160) && (x < Rxmax) && (y > Rymin + 94) && (y < Rymax)) || //Right of R
				((x > Oxmin + 50) && (x < Oxmax - 50) && (y > Oymin + 50) && (y < Oymax - 50)) || //Middle of O
				((x > S1xmin + 50) && (x < S1xmax) && (y > S1ymin + 50) && (y < S1ymax - 150)) || //Top of S1
				((x > S1xmin) && (x < S1xmax - 50) && (y > S1ymin + 150) && (y < S1ymax - 50)) || //Bottom of S1
				((x > S2xmin + 50) && (x < S2xmax) && (y > S2ymin + 50) && (y < S2ymax - 150)) || //Top of S2
				((x > S2xmin) && (x < S2xmax - 50) && (y > S2ymin + 150) && (y < S2ymax - 50)) //Bottom of  S2
				) 
			begin
				vid_d1 <= (flip) ? {Y_black, CB_black} : {Y_black, CR_black};
			end
		end
		
		/* -- MOVEMENT */
		// move every frame
		if (VFall) begin
			
			// vid_split_i = 1 --> split characters
			if (vid_split_i) begin
				if (!current_split) begin
					// ensure splitting to different directions
					incRx <= 0;
					incRy <= 1;
					incOx <= 0;
					incOy <= 0;
					incS1x <= 1;
					incS1y <= 0;
					incS2x <= 1;
					incS2y <= 1;
				end
				
				// send split signal
				current_split <= 1;
			
				// move R
				if (Rxmax >= X_COORD_MAX) begin
					incRx <= 0;
				end else if (Rxmin <= 0) begin
					incRx <= 1;
				end
				
				if (incRx) begin
					Rxmin <= Rxmin + speed;
					Rxmax <= Rxmax + speed;
				end else begin
					Rxmin <= Rxmin - speed;
					Rxmax <= Rxmax - speed;
				end
				
				if (Rymax >= Y_COORD_MAX) begin
					incRy <= 0;
				end else if (Rymin <= 0) begin
					incRy <= 1;
				end
				
				if (incRy) begin
					Rymin <= Rymin + speed;
					Rymax <= Rymax + speed;
				end else begin
					Rymin <= Rymin - speed;
					Rymax <= Rymax - speed;
				end
				
				// move O
				if (Oxmax >= X_COORD_MAX) begin
					incOx <= 0;
				end else if (Oxmin <= 0) begin
					incOx <= 1;
				end
				
				if (incOx) begin
					Oxmin <= Oxmin + speed;
					Oxmax <= Oxmax + speed;
				end else begin
					Oxmin <= Oxmin - speed;
					Oxmax <= Oxmax - speed;
				end
				
				if (Oymax >= Y_COORD_MAX) begin
					incOy <= 0;
				end else if (Oymin <= 0) begin
					incOy <= 1;
				end
				
				if (incOy) begin
					Oymin <= Oymin + speed;
					Oymax <= Oymax + speed;
				end else begin
					Oymin <= Oymin - speed;
					Oymax <= Oymax - speed;
				end
				
				// move S1
				if (S1xmax >= X_COORD_MAX) begin
					incS1x <= 0;
				end else if (S1xmin <= 0) begin
					incS1x <= 1;
				end
				
				if (incS1x) begin
					S1xmin <= S1xmin + speed;
					S1xmax <= S1xmax + speed;
				end else begin
					S1xmin <= S1xmin - speed;
					S1xmax <= S1xmax - speed;
				end
				
				if (S1ymax >= Y_COORD_MAX) begin
					incS1y <= 0;
				end else if (S1ymin <= 0) begin
					incS1y <= 1;
				end
				
				if (incS1y) begin
					S1ymin <= S1ymin + speed;
					S1ymax <= S1ymax + speed;
				end else begin
					S1ymin <= S1ymin - speed;
					S1ymax <= S1ymax - speed;
				end
				
				// move S2
				if (S2xmax >= X_COORD_MAX) begin
					incS2x <= 0;
				end else if (S2xmin <= 0) begin
					incS2x <= 1;
				end
				
				if (incS2x) begin
					S2xmin <= S2xmin + speed;
					S2xmax <= S2xmax + speed;
				end else begin
					S2xmin <= S2xmin - speed;
					S2xmax <= S2xmax - speed;
				end
				
				if (S2ymax >= Y_COORD_MAX) begin
					incS2y <= 0;
				end else if (S2ymin <= 0) begin
					incS2y <= 1;
				end
				
				if (incS2y) begin
					S2ymin <= S2ymin + speed;
					S2ymax <= S2ymax + speed;
				end else begin
					S2ymin <= S2ymin - speed;
					S2ymax <= S2ymax - speed;
				end
	
			end else begin
				// return from split
				if (current_split) begin
					// move R to center
					if (Rxmin < RX_MIN_START) begin
						if (RX_MIN_START - Rxmin < speed) begin
							Rxmin <= Rxmin + 1;
							Rxmax <= Rxmax + 1;
						end else begin
							Rxmin <= Rxmin + speed;
							Rxmax <= Rxmax + speed;
						end
					end
					if (Rxmin > RX_MIN_START) begin
						if (Rxmin - RX_MIN_START < speed) begin
							Rxmin <= Rxmin - 1;
							Rxmax <= Rxmax - 1;
						end else begin
							Rxmin <= Rxmin - speed;
							Rxmax <= Rxmax - speed;
						end
					end
					if (Rymin < RY_MIN_START) begin
						if (Rymin - RY_MIN_START < speed) begin
							Rymin <= Rymin + 1;
							Rymax <= Rymax + 1;
						end else begin
							Rymin <= Rymin + speed;
							Rymax <= Rymax + speed;
						end
					end
					if (Rymin > RY_MIN_START) begin
						if (Rymin - RY_MIN_START < speed) begin
							Rymin <= Rymin - 1;
							Rymax <= Rymax - 1;
						end else begin
							Rymin <= Rymin - speed;
							Rymax <= Rymax - speed;
						end
					end
					
					// move O to center
					if (Oxmin < OX_MIN_START) begin
						if (OX_MIN_START - Oxmin < speed) begin
							Oxmin <= Oxmin + 1;
							Oxmax <= Oxmax + 1;
						end else begin
							Oxmin <= Oxmin + speed;
							Oxmax <= Oxmax + speed;
						end
					end
					if (Oxmin > OX_MIN_START) begin
						if (Oxmin - OX_MIN_START < speed) begin
							Oxmin <= Oxmin - 1;
							Oxmax <= Oxmax - 1;
						end else begin
							Oxmin <= Oxmin - speed;
							Oxmax <= Oxmax - speed;
						end
					end
					if (Oymin < OY_MIN_START) begin
						if (Oymin - OY_MIN_START < speed) begin
							Oymin <= Oymin + 1;
							Oymax <= Oymax + 1;
						end else begin
							Oymin <= Oymin + speed;
							Oymax <= Oymax + speed;
						end
					end
					if (Oymin > OY_MIN_START) begin
						if (Oymin - OY_MIN_START < speed) begin
							Oymin <= Oymin - 1;
							Oymax <= Oymax - 1;
						end else begin
							Oymin <= Oymin - speed;
							Oymax <= Oymax - speed;
						end
					end
					
					// move S1 to center
					if (S1xmin < S1X_MIN_START) begin
						if (S1X_MIN_START - S1xmin < speed) begin
							S1xmin <= S1xmin + 1;
							S1xmax <= S1xmax + 1;
						end else begin
							S1xmin <= S1xmin + speed;
							S1xmax <= S1xmax + speed;
						end
					end
					if (S1xmin > S1X_MIN_START) begin
						if (S1xmin - S1X_MIN_START < speed) begin
							S1xmin <= S1xmin - 1;
							S1xmax <= S1xmax - 1;
						end else begin
							S1xmin <= S1xmin - speed;
							S1xmax <= S1xmax - speed;
						end
					end
					if (S1ymin < S1Y_MIN_START) begin
						if (S1ymin - S1Y_MIN_START < speed) begin
							S1ymin <= S1ymin + 1;
							S1ymax <= S1ymax + 1;
						end else begin
							S1ymin <= S1ymin + speed;
							S1ymax <= S1ymax + speed;
						end
					end
					if (S1ymin > S1Y_MIN_START) begin
						if (S1ymin - S1Y_MIN_START < speed) begin
							S1ymin <= S1ymin - 1;
							S1ymax <= S1ymax - 1;
						end else begin
							S1ymin <= S1ymin - speed;
							S1ymax <= S1ymax - speed;
						end
					end
					
					// move S2 to center
					if (S2xmin < S2X_MIN_START) begin
						if (S2X_MIN_START - S2xmin < speed) begin
							S2xmin <= S2xmin + 1;
							S2xmax <= S2xmax + 1;
						end else begin
							S2xmin <= S2xmin + speed;
							S2xmax <= S2xmax + speed;
						end
					end
					if (S2xmin > S2X_MIN_START) begin
						if (S2xmin - S2X_MIN_START < speed) begin
							S2xmin <= S2xmin - 1;
							S2xmax <= S2xmax - 1;
						end else begin
							S2xmin <= S2xmin - speed;
							S2xmax <= S2xmax - speed;
						end
					end
					if (S2ymin < S2Y_MIN_START) begin
						if (S2ymin - S2Y_MIN_START < speed) begin
							S2ymin <= S2ymin + 1;
							S2ymax <= S2ymax + 1;
						end else begin
							S2ymin <= S2ymin + speed;
							S2ymax <= S2ymax + speed;
						end
					end
					if (S2ymin > S2Y_MIN_START) begin
						if (S2ymin - S2Y_MIN_START < speed) begin
							S2ymin <= S2ymin - 1;
							S2ymax <= S2ymax - 1;
						end else begin
							S2ymin <= S2ymin - speed;
							S2ymax <= S2ymax - speed;
						end
					end
					
					// all letters at center, start moving them all at once
					if (Rxmin == RX_MIN_START && Rymin == RY_MIN_START 
					&&  Oxmin == OX_MIN_START && Oymin == OY_MIN_START 
					&&  S1xmin == S1X_MIN_START && S1ymin == S1Y_MIN_START
					&&  S2xmin == S2X_MIN_START && S2ymin == S2Y_MIN_START) begin
						current_split = 0;
					end
				
				end else begin
					// vid_split_i = 0 -> move all characters together
				
					//horizontal direction
					if(S2xmax >= X_COORD_MAX) begin
						incX <= 0;
					end else if (Rxmin <= 0) begin
						incX <= 1;
					end
					
					if(incX) begin
						Rxmin <= Rxmin + speed;
						Rxmax <= Rxmax + speed;
						Oxmin <= Oxmin + speed;
						Oxmax <= Oxmax + speed;
						S1xmin <= S1xmin + speed;
						S1xmax <= S1xmax + speed;
						S2xmin <= S2xmin + speed;
						S2xmax <= S2xmax + speed;
					end else begin
						Rxmin <= Rxmin - speed;
						Rxmax <= Rxmax - speed;
						Oxmin <= Oxmin - speed;
						Oxmax <= Oxmax - speed;
						S1xmin <= S1xmin - speed;
						S1xmax <= S1xmax - speed;
						S2xmin <= S2xmin - speed;
						S2xmax <= S2xmax - speed;
					end
					
					//vertical direction
					if(Rymax >= Y_COORD_MAX) begin
						incY <= 0;
						
					end else if(Rymin <= 0) begin
						incY <= 1;
					end
					
					if(incY) begin
						Rymin <= Rymin + speed;
						Rymax <= Rymax + speed;
						Oymin <= Rymin + speed;
						Oymax <= Rymax + speed;
						S1ymin <= Rymin + speed;
						S1ymax <= Rymax + speed;
						S2ymin <= Rymin + speed;
						S2ymax <= Rymax + speed;
						
					end else begin
						Rymin <= Rymin - speed;
						Rymax <= Rymax - speed;
						Oymin <= Oymin - speed;
						Oymax <= Oymax - speed;
						S1ymin <= S1ymin - speed;
						S1ymax <= S1ymax - speed;
						S2ymin <= S2ymin - speed;
						S2ymax <= S2ymax - speed;
					end	
				end
			end	
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