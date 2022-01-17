module wav_player( rst, clk, play, mclk, lrck, sck, sdin );
    parameter PLAY = 1'b1;
    parameter PAUSE = 1'b0; 
    localparam ADDR_SIZE = 120187;

    input clk, rst;
    input play;
    output mclk, lrck, sck, sdin;

    wire play_db, play_op, rst_db, rst_op;
    wire clk_d2,clk_d3, clk_8000;

    clk_div #(2) CD2 (clk, clk_d2);

    // 8000 hz ~= 100Mhz /3 /2^12
    clk_3 CD0 (clk, clk_d3);
    clk_div #(12) CD1 (clk_d3, clk_8000);

    debounce DB0(play, play_db, clk_d2);
    debounce DB1(rst, rst_db, clk_d2);
    onepulse OP0(play_db, play_op, clk_8000);
    onepulse OP1(rst_db, rst_op, clk_8000);


    
    reg [16:0] address;
    wire [16:0] next_addr;
    wire [7:0] temp, audio_stream;
    reg [7:0] data;
    reg state, next_state;

    always @(posedge clk_8000 ) begin
        if (rst_op == 1'b1)begin
            state <= PAUSE;
            address <= 17'b0;
        end
        else begin
            if (state == PLAY) begin
                address <= next_addr;
                state <= next_state;
            end
            else begin
                address <= address;
                state <= next_state;
            end
        end
    end

    always @(*) begin
        if (state == PLAY) begin
            if (play_op || address == ADDR_SIZE) begin
                next_state = PAUSE;
            end
            else begin
                next_state = PLAY;
            end
        end
        else begin
            if (play_op) begin
                next_state = PLAY;
            end
            else begin
                next_state = PAUSE;
            end
        end
    end

    assign next_addr = (address == ADDR_SIZE) ? 17'b0 : address + 1 ;

    // address in stream out
    blk_mem_gen_0 BMG0(
		.clka(clk_d2),
        .wea(1'b0),
        .addra(address),
        .dina(temp),
        .douta(audio_stream)
    ); 
    
    // to stablelize memory output
    always @(posedge clk ) begin
        data <= audio_stream;
    end

    // extend 8 bit to 16 bit 
    wire [15:0] audio_data = {data, {8{data[7]}}};
    speaker_control test (clk, 1'b0, audio_data, audio_data, mclk, lrck, sck, sdin);

endmodule

module clk_3(clk, clk_div);
    input clk;
    output clk_div;
    reg [1:0] clk_num = 0;
    always @(posedge clk ) begin
        if (clk_num == 2'b10) begin
            clk_num <= 2'b0;
        end
        else begin
            clk_num <= clk_num +1;
        end
    end
    assign clk_div = clk_num[1];
endmodule

module onepulse(s, s_op, clk);
	input s, clk;
	output reg s_op;
	reg s_delay;
	always@(posedge clk)begin
		s_op <= s&(!s_delay);
		s_delay <= s;
	end
endmodule

module debounce(s, s_db, clk);
	input s, clk;
	output s_db;
	reg [3:0] DFF;
	
	always@(posedge clk)begin
		DFF[3:1] <= DFF[2:0];
		DFF[0] <= s;
	end
	assign s_db = (DFF == 4'b1111)? 1'b1 : 1'b0;
endmodule

module clk_div #(parameter n = 2)(clk, clk_d);
	input clk;
	output clk_d;
	reg [n-1:0]count;
	wire[n-1:0]next_count;
	
	always@(posedge clk)begin
		count <= next_count;
	end
	
	assign next_count = count + 1;
	assign clk_d = count[n-1];
endmodule

module speaker_control(
    clk,  // clock from the crystal
    rst,  // active high reset
    audio_in_left, // left channel audio data input
    audio_in_right, // right channel audio data input
    audio_mclk, // master clock
    audio_lrck, // left-right clock, Word Select clock, or sample rate clock
    audio_sck, // serial clock
    audio_sdin // serial audio data input
);

    // I/O declaration
    input clk;  // clock from the crystal
    input rst;  // active high reset
    input [15:0] audio_in_left; // left channel audio data input
    input [15:0] audio_in_right; // right channel audio data input
    output audio_mclk; // master clock
    output audio_lrck; // left-right clock
    output audio_sck; // serial clock
    output audio_sdin; // serial audio data input
    reg audio_sdin;

    // Declare internal signal nodes 
    wire [8:0] clk_cnt_next;
    reg [8:0] clk_cnt;
    reg [15:0] audio_left, audio_right;

    // Counter for the clock divider
    assign clk_cnt_next = clk_cnt + 1'b1;

    always @(posedge clk or posedge rst)
        if (rst == 1'b1)
            clk_cnt <= 9'd0;
        else
            clk_cnt <= clk_cnt_next;

    // Assign divided clock output
    assign audio_mclk = clk_cnt[1];
    assign audio_lrck = clk_cnt[8];
    assign audio_sck = 1'b1; // use internal serial clock mode

    // audio input data buffer
    always @(posedge clk_cnt[8] or posedge rst)
        if (rst == 1'b1)
            begin
                audio_left <= 16'd0;
                audio_right <= 16'd0;
            end
        else
            begin
                audio_left <= audio_in_left;
                audio_right <= audio_in_right;
            end

    always @*
        case (clk_cnt[8:4])
            5'b00000: audio_sdin = audio_right[0];
            5'b00001: audio_sdin = audio_left[15];
            5'b00010: audio_sdin = audio_left[14];
            5'b00011: audio_sdin = audio_left[13];
            5'b00100: audio_sdin = audio_left[12];
            5'b00101: audio_sdin = audio_left[11];
            5'b00110: audio_sdin = audio_left[10];
            5'b00111: audio_sdin = audio_left[9];
            5'b01000: audio_sdin = audio_left[8];
            5'b01001: audio_sdin = audio_left[7];
            5'b01010: audio_sdin = audio_left[6];
            5'b01011: audio_sdin = audio_left[5];
            5'b01100: audio_sdin = audio_left[4];
            5'b01101: audio_sdin = audio_left[3];
            5'b01110: audio_sdin = audio_left[2];
            5'b01111: audio_sdin = audio_left[1];
            5'b10000: audio_sdin = audio_left[0];
            5'b10001: audio_sdin = audio_right[15];
            5'b10010: audio_sdin = audio_right[14];
            5'b10011: audio_sdin = audio_right[13];
            5'b10100: audio_sdin = audio_right[12];
            5'b10101: audio_sdin = audio_right[11];
            5'b10110: audio_sdin = audio_right[10];
            5'b10111: audio_sdin = audio_right[9];
            5'b11000: audio_sdin = audio_right[8];
            5'b11001: audio_sdin = audio_right[7];
            5'b11010: audio_sdin = audio_right[6];
            5'b11011: audio_sdin = audio_right[5];
            5'b11100: audio_sdin = audio_right[4];
            5'b11101: audio_sdin = audio_right[3];
            5'b11110: audio_sdin = audio_right[2];
            5'b11111: audio_sdin = audio_right[1];
            default: audio_sdin = 1'b0;
        endcase

endmodule


module divider #(parameter n = 2) (clk, clk_div);//100MHz / 2^25
    // parameter n = 25;
    input clk;
    output clk_div;
    reg [n-1:0]num = 0;
    wire [n-1:0]next_num;
    
    always @(posedge clk) begin
        num <= next_num;
    end
    assign next_num = num + 1;
    assign clk_div = num[n-1];
endmodule