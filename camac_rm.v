//////////////////////////////////////////////////////////////////////////////////
// Company:        Tohoku Univ.
// Engineer:       Kenji Hosomi
// 
// Create Date:    17:35:36 12/11/2008 
// Design Name:    camac_rm
// Module Name:    camac_rm.v 
// Project Name:   cacac_rm.ise
// Target Devices: XC95288XL-10PQ208C
// Tool versions:  Xilinx ISE 10.1.03
// Description: 
//
// Dependencies:   camac_rm.ucf 
//
// Revision:       09/25/2009 version 1.0
//           
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module camac_rm(
					 SYSCLK,
					 ENC,SNC,TRIG1,TRIG2,RSV2IN,LOCK,
					 BSYOUT,RSV2OUT,BSY1IN,BSY2IN,LATCH,REGIN,
					 CRDATA,F,A,S1,S2,C,N,B,Z,I,
					 CWDATA,OE,X,L,Q,
					 LED1,LED2,LED3
              );
//==============================================================================
//                    Difinition of I/O signals
//==============================================================================

	input         SYSCLK;       // System Clock (50MHz)
	
//=== IO Rear Panel RJ45 ===
	input [13:0]  ENC;          // Event Number Counter
	input [9:0]   SNC;          // Spill Number Counter
	input         TRIG1;        // Trigger1
	input         TRIG2;        // Trigger2
	input         LOCK;         // Lock
	
	output        BSYOUT;
	output        RSV2OUT;

//=== IO Front Panel NIM ===
	input         RSV2IN;       // Reserve2
	input         BSY1IN;       // Busy1
	input         BSY2IN;       // Busy2
	input         LATCH;        // Latch
	input [15:0]  REGIN;        // 16bit Input Register
	
	
//=== IO CAMAC bus ===
	input [7:0]   CWDATA;       // 8bit Write Line
	input [4:0]   F;            // Function
	input [3:0]   A;            // Sub Address
	input         S1;           // Strobe Signal 1
	input         S2;           // Strobe Signal 2
	input         C;            // Clear
	input         N;            // Station Number
	input         B;            // Busy
	input         Z;            // Initialize
	input			  I;            // Inhibit
	
	output [15:0] CRDATA;       // 16bit Read Line
	output        OE;           // 3-STATE Output Enable
	output        X;            // Command Accepted (1:FALSE, 0:TURE)
	output        Q;            // Response (1:FALSE, 0:TURE)
	output        L;            // Lock at me (1:FALSE, 0:TURE)
	
//=== Front Panel LED ===
   output        LED1;        // LED T1
	output        LED2;        // LED T2
	output        LED3;        // LED BSY

//==============================================================================
//          CAMAC registers
//==============================================================================
	reg  [15:0] camac_reg0 =16'd0;  //event number
	reg  [15:0] camac_reg1 =16'd0;  //spill number
	reg  [15:0] camac_reg2 =16'd0;  //serial
	reg  [15:0] camac_reg3 =16'd0;  //dummy
	reg  [15:0] camac_reg4 =16'd0;  //input register
	reg  [15:0] camac_reg5 =16'd0;  //lock at me

//==============================================================================
//          signal assign
//==============================================================================
  
   wire clear;   //camac C
	wire init;    //camac Z

	assign RSV2OUT  = RSV2IN;
	assign BSYOUT   = BSY1IN | BSY2IN;
	
	//wire strig1;
	//async_input_sync sync1(SYSCLK, TRIG1, strig1);
	wire strig2;
	async_input_sync sync2(SYSCLK, TRIG2, strig2);

	ledon led1( SYSCLK, TRIG1, LED1 );
	ledon led2( SYSCLK, TRIG2, LED2 );
	ledon led3( SYSCLK, BSY1IN | BSY2IN, LED3 );

	 //Event and Spill tag
	reg [1:0] trig2_e=2'd0;
	always @ (posedge SYSCLK) begin
		trig2_e <= {trig2_e[0],strig2};
	end
	
	always @ (posedge SYSCLK) begin
	   if( clear | init ) begin
		   camac_reg0 <= 16'd0;
			camac_reg1 <= 16'd0;
			camac_reg5 <= 16'd0;
		end
		else if( trig2_e==2'b01 && !I ) begin
			camac_reg0 <= {LOCK, 3'd0, ENC[13:2]};
			camac_reg1 <= {LOCK, 7'd0, SNC[7:0]};
			camac_reg5 <= 16'd1;
		end
	end

	//Input register
	wire slatch;
	async_input_sync sync3(SYSCLK, LATCH, slatch);
	
	reg [1:0] latch_e=2'd0;
	always @ (posedge SYSCLK) begin
		latch_e <= {latch_e[0],slatch};
	end
	
	always @ (posedge SYSCLK) begin
		if( clear | init ) camac_reg4 <= 16'd0;
		if( latch_e==2'b01 && !I ) camac_reg4 <= REGIN;
	end

//==============================================================================
//          CAMAC cycle
//==============================================================================
   assign L = 1'b1;

   wire ss1, ss2, sn;
	async_input_sync sync4(SYSCLK, S1, ss1);
	async_input_sync sync5(SYSCLK, S2, ss2);
	async_input_sync sync6(SYSCLK, N, sn);
	
	reg [1:0] s1_e=2'd0;
	reg [1:0] n_e=2'd0;
	always @ (posedge SYSCLK) begin
		s1_e <= {s1_e[0],ss1 & B & N};
		n_e <= {n_e[0],sn & B};
	end

   //C, Z response	
	assign clear = C & B & ss2;
	assign init  = Z & B & ss2;
		
	//read, write response
	reg Q = 1'b1;
	reg X = 1'b1;
	reg OE= 1'b1;
	always @ ( posedge SYSCLK ) begin
		if ( clear | init ) begin
				X			<=	1'b1;
				Q			<=	1'b1;
				OE 		<=	1'b1;
		end
		else if ( n_e == 2'b11 ) begin
				case ( {F,A} )
					{5'd0, 4'd0}: begin
											X			<=	1'b0;
											Q			<=	1'b0;
											OE 		<=	1'b0;
					              end
					{5'd0, 4'd1}: begin
											X			<=	1'b0;
											Q			<=	1'b0;
											OE 		<=	1'b0;
					              end
					{5'd0, 4'd2}: begin
											X			<=	1'b0;
											Q			<=	1'b0;
											OE 		<=	1'b0;
					              end
					{5'd0, 4'd3}: begin
											X			<=	1'b0;
											Q			<=	1'b0;
											OE 		<=	1'b0;
					              end
					{5'd0, 4'd4}: begin
											X			<=	1'b0;
											Q			<=	1'b0;
											OE 		<=	1'b0;
					              end
					{5'd0, 4'd5}: begin
											X			<=	1'b0;
											Q			<=	1'b0;
											OE 		<=	1'b0;
					              end				  
               {5'd16, 4'd3}: begin
											X			<=	1'b0;
											Q			<=	1'b0;
											OE 		<=	1'b1;
					              end
					default: begin
											X			<=	1'b1;
											Q			<=	1'b1;
											OE 		<=	1'b1;
					              end
			  endcase
		end
		else begin
			   X			<=	1'b1;
			   Q			<=	1'b1;
				OE 		<=	1'b1;
		end
	end

	
	//camac read
	assign CRDATA	=	~( camac_data_select( {F,A}, camac_reg0, camac_reg1, camac_reg2, camac_reg3, camac_reg4, camac_reg5 ) );
	
	function [15:0] camac_data_select;
	input [8:0]  FA;
	input [15:0] camac_reg0, camac_reg1, camac_reg2, camac_reg3, camac_reg4, camac_reg5;
		case ( FA )
			{5'd0,4'd0}:			camac_data_select = camac_reg0;
			{5'd0,4'd1}:			camac_data_select = camac_reg1;
			{5'd0,4'd2}:			camac_data_select = camac_reg2;
			{5'd0,4'd3}:			camac_data_select = camac_reg3;
			{5'd0,4'd4}:			camac_data_select = camac_reg4;
			{5'd0,4'd5}:			camac_data_select = camac_reg5;
			default:					camac_data_select = 16'd0;
		endcase
	endfunction

	always @ (posedge SYSCLK) begin
	   if( clear | init ) begin
		   camac_reg2 <= 16'd0;
		end
		else if( n_e==2'b01 ) begin
			if({F,A}=={5'd0, 4'd2}) camac_reg2 <= camac_reg2 + 16'd1;
		end
	end


   //camac write
	always @ (posedge SYSCLK) begin
	   if( clear | init ) begin
		   camac_reg3 <= 16'd0;
		end
		else if( s1_e==2'b01 ) begin
			if({F,A}=={5'd16, 4'd3}) camac_reg3 <= {8'd0, CWDATA};
		end
	end
	
		
endmodule


module ledon(clk, in, out);

	input  clk,in;
	output reg out=1'b0;
	
	reg [15:0] counter  = 16'd0;
	parameter  maxcount = 50000; //20ns*50000=1ms
	
	always @ ( posedge clk )	begin
	   if ( in ) begin
				out     <= 1'b1;
				counter <= 16'd1;
		end
		else if ( counter > maxcount )	begin
				out     <= 1'b0;
				counter <= 16'd0;
		end
		else if ( counter > 16'd0 ) begin
				out	  <= 1'b1;
				counter <= counter + 16'd1;
		end
		else begin
				out     <= 1'b0;
				counter <= 16'd0;
		end
	end
endmodule

module async_input_sync(
   input clk,
   (* TIG="TRUE", IOB="FALSE" *) input async_in,
   output reg sync_out
);

   (* ASYNC_REG="TRUE", SHIFT_EXTRACT="NO", HBLKNM="sync_reg" *) reg [1:0] sreg;                                                                           
   always @(posedge clk) begin
     sync_out <= sreg[1];
     sreg <= {sreg[0], async_in};
   end

endmodule
				