// This is HVL for FPU verification environment that runs on the Workstation

import scemi_pipes_pkg::*; 	// For trans-language TLM channels.
import definitions::*;		// Provides custom type such as float_t, fpu_instruction_t
import randomizer::*;		// provides randomized constraints

//File Handlers
int		output_file;
int		input_file;
int		error_file;

//local parameters
localparam data_width =	32;

//SystemVerilog Queue to store test cases that were sent to the DUT
//These are popped and given to the golden model once a result is obtained from the emulator 
fpu_instruction_t 	sent_queue [$];

//Since DUT outputs a result of "zero" during reset, it is ignored by startup variable
int startup = 0;

//When debug is 1, results are printed on terminal
parameter debug=0;

//When file is 1, the inputs given to DUT, 
//obtained and expected outputs  are written to text files
parameter file = 1;

//keeps track of total number of errors
int error_count;

//Scoreboard class
//This class monitors the output pipe. It creates a new object for outputpipe 
// A task runs continuously monitoring the output pipe 
class scoreboard;
	
	//Class attributes
	float_t 					opa;
	float_t						opb;
	float_t 					actual_result;
	byte						actual_flag_vector; 
	shortreal					expected_result;
	flags_t						expected_flag_vector;
	fpu_instruction_t			sent_instruction;
	scemi_dynamic_output_pipe 	monitorChannel;
	
	//constructor
	function new ();
	begin
		//instantiates the output pipe
		monitorChannel = new ("top.outputpipe");
		
		//setup the file handle
		if(file) 
		begin
			output_file	= 	$fopen("output.txt","w");
			error_file 	=	$fopen("error.txt","w");
			$fwrite(output_file,"Output\n");
			$fwrite(error_file,"Errors\n");
		end
		
	end
	endfunction
	
	//generates the expected result based on the inputs given to the DUT
	function void generate_expected_result();
		
		//pop the instruction which was sent earlier 
		sent_instruction=sent_queue.pop_front;	
		
		case(sent_instruction.fpu_op)
		
			ADD		:	expected_result = $bitstoshortreal(sent_instruction.opa) + $bitstoshortreal(sent_instruction.opb); 
			SUB		:	expected_result = $bitstoshortreal(sent_instruction.opa) - $bitstoshortreal(sent_instruction.opb); 
			MULT	:	expected_result = $bitstoshortreal(sent_instruction.opa) * $bitstoshortreal(sent_instruction.opb); 
			DIV		:	expected_result = $bitstoshortreal(sent_instruction.opa) / $bitstoshortreal(sent_instruction.opb); 
			SQRT	:	expected_result = $sqrt($bitstoshortreal(sent_instruction.opa)); 
		
		endcase
		
		generate_expected_flags();
	endfunction
	
	//generates most of the expected flags
	function void generate_expected_flags();
		
		float_t		result 		= $shortrealtobits(expected_result);
		expected_flag_vector 	= 8'b0000_0000;
		
		expected_flag_vector.inexact = 1'b1;
		if(result.exponent === 8'b0000_0000)
			if(result.mantissa === {23{1'b0}})
			begin
				expected_flag_vector.zero = 1'b1;	
				expected_flag_vector.underflow = 1'b1;
			end
			else
				expected_flag_vector.underflow = 1'b1;
				
		
		if(result.exponent === 8'b1111_1111)
			if(result.mantissa !== {23{1'b0}})
			begin
				expected_flag_vector.qnan = 1'b1;
				expected_flag_vector.snan = 1'b1;
				expected_flag_vector.inexact = 1'b0;
			end
			else
			begin
				expected_flag_vector.infinity = 1'b1;
				expected_flag_vector.overflow = 1'b1;
			end

								
					
	
	endfunction
	
	//checks the correctness of the expected and obtained results
	//increments the error_count if there is an error
	function void verify_results();
		
		if(sent_instruction.fpu_op == SQRT)
		begin
			//since the squareroot algorithm is not precise, need to consider +- 0.002
			if(expected_result < ( $bitstoshortreal(actual_result) * 0.998 ) ||
			expected_result > ( $bitstoshortreal(actual_result) * 1.002 ))
			begin
				write_errors(1);				
				error_count++;						
			end
		end
		else
		begin
			if(expected_result != $bitstoshortreal(actual_result))		//If obtained and expected products don't match, its an error
			begin
				write_errors(1);				
				error_count++;
			
			end
		end
		
		//verifying flags
		
		if(expected_flag_vector.infinity !== actual_flag_vector[7])
			write_errors(5);
			
		if(expected_flag_vector.snan || expected_flag_vector.qnan)
			begin
				if(!(actual_flag_vector[6] || actual_flag_vector[5]))
					write_errors(5);
			end
		
		if(expected_flag_vector.overflow !== actual_flag_vector[3])
			write_errors(5);
			
		if(expected_flag_vector.underflow !== actual_flag_vector[2])
			write_errors(5);
		
											
	endfunction

	//writes details to the output file
	function void write_outputs(int float_format=1);
	
		bit [31:0] expected_result_bits = $shortrealtobits(expected_result);
		if(file)
		begin
			case (float_format)
				
				//writes everything in binary format
				0 : $fwrite(output_file,"opcode : %4s, rmode : %18s,\topa : %b, \topb : %b \tflag : %b , actual_result : %b_%b_%b, expected result : %b %b %b \n", 
					sent_instruction.fpu_op.name(), sent_instruction.rmode.name(),
					sent_instruction.opa, sent_instruction.opb,
					actual_flag_vector,actual_result.sign,actual_result.exponent,actual_result.mantissa,
					expected_result_bits[31], expected_result_bits[30:23], expected_result_bits[22:0]);
				
				//writes everything in floating point format
				1 : $fwrite(output_file,"opcode : %4s, rmode : %18s, opa : %15f, opb : %15f, flag : %b , actual_result : %15f, expected result : %15f \n", 
					sent_instruction.fpu_op.name(), sent_instruction.rmode.name(),
					$bitstoshortreal(sent_instruction.opa), $bitstoshortreal(sent_instruction.opb),
					actual_flag_vector,$bitstoshortreal(actual_result),expected_result);
				
				//writes only rounding mode and output in binary format
				2 : $fwrite(output_file,"rmode : %18s,flag : %b , actual_result : %b %b %b, expected result : %b %b %b \n",
					sent_instruction.rmode.name(),actual_flag_vector,
					actual_result.sign,actual_result.exponent,actual_result.mantissa,
					expected_result_bits[31], expected_result_bits[30:23], expected_result_bits[22:0]);
				
				//writes only input operands and output in binary format
				3 : $fwrite(output_file,"opa : %b %b %b, opb : %b %b %b, af : %b, ef : %b, ar : %b %b %b, er : %b %b %b \n",
					sent_instruction.opa.sign,sent_instruction.opa.exponent, sent_instruction.opa.mantissa,
					sent_instruction.opb.sign,sent_instruction.opb.exponent, sent_instruction.opb.mantissa,
					actual_flag_vector,expected_flag_vector, actual_result.sign,actual_result.exponent,actual_result.mantissa,
					expected_result_bits[31], expected_result_bits[30:23], expected_result_bits[22:0]);
					
				//writes only input operands in float and output in binary format
				4 : $fwrite(output_file,"opa : %30f, opb : %30f, af : %b , ef : %b, ar : %b %b %b, er : %b %b %b \n",
					$bitstoshortreal(sent_instruction.opa), $bitstoshortreal(sent_instruction.opb),					
					actual_flag_vector,expected_flag_vector, actual_result.sign,actual_result.exponent,actual_result.mantissa,
					expected_result_bits[31], expected_result_bits[30:23], expected_result_bits[22:0]);
				
			endcase
			
		end
	
	endfunction
	
	//writes the details to error file
	function void write_errors(int float_format=1);
	
		bit [31:0] expected_result_bits = $shortrealtobits(expected_result);
		if(file)
		begin
			case (float_format)
				
				//writes everything in binary format
				0 : $fwrite(error_file,"opcode : %4s, rmode : %18s, opa : %b, opb : %b, af : %b, ef : %b, ar : %b %b %b, er : %b %b %b \n", 
					sent_instruction.fpu_op.name(), sent_instruction.rmode.name(),
					sent_instruction.opa, sent_instruction.opb,
					actual_flag_vector,expected_flag_vector,actual_result.sign,actual_result.exponent,actual_result.mantissa,
					expected_result_bits[31], expected_result_bits[30:23], expected_result_bits[22:0]);
				
				//writes everything in floating point format
				1 : $fwrite(error_file,"opcode : %4s, rmode : %18s, opa : %15f, opb : %15f, af : %b, ef : %b, ar : %15f, er : %15f \n", 
					sent_instruction.fpu_op.name(), sent_instruction.rmode.name(),
					$bitstoshortreal(sent_instruction.opa), $bitstoshortreal(sent_instruction.opb),
					actual_flag_vector,expected_flag_vector,$bitstoshortreal(actual_result),expected_result);
					
				//writes everything in binary format except operands 
				2 : $fwrite(error_file,"opcode : %4s, rmode : %18s, opa : %15f, opb : %15f, af : %b, ef : %b, ar : %b %b %b, er : %b %b %b \n", 
					sent_instruction.fpu_op.name(), sent_instruction.rmode.name(),
					$bitstoshortreal(sent_instruction.opa), $bitstoshortreal(sent_instruction.opb),
					actual_flag_vector,expected_flag_vector,actual_result.sign,actual_result.exponent,actual_result.mantissa,
					expected_result_bits[31], expected_result_bits[30:23], expected_result_bits[22:0]);
				
				//writes only input operands and output in binary format
				3 : $fwrite(error_file,"opa : %b %b %b, opb : %b %b %b, af : %b, ef : %b, ar : %b %b %b, er : %b %b %b \n",
					sent_instruction.opa.sign,sent_instruction.opa.exponent, sent_instruction.opa.mantissa,
					sent_instruction.opb.sign,sent_instruction.opb.exponent, sent_instruction.opb.mantissa,
					actual_flag_vector,expected_flag_vector, actual_result.sign,actual_result.exponent,actual_result.mantissa,
					expected_result_bits[31], expected_result_bits[30:23], expected_result_bits[22:0]);
					
				//writes only input operands in float and output in binary format
				4 : $fwrite(error_file,"opa : %30f, opb : %30f, af : %b , ef : %b, ar : %b %b %b, er : %b %b %b \n",
					$bitstoshortreal(sent_instruction.opa), $bitstoshortreal(sent_instruction.opb),					
					actual_flag_vector,expected_flag_vector, actual_result.sign,actual_result.exponent,actual_result.mantissa,
					expected_result_bits[31], expected_result_bits[30:23], expected_result_bits[22:0]);
					
				//writes everything in binary format
				5 : $fwrite(error_file,"Error in flags::: opcode : %4s, rmode : %18s, opa : %b, opb : %b, af : %b, ef : %b, ar : %b %b %b, er : %b %b %b \n", 
					sent_instruction.fpu_op.name(), sent_instruction.rmode.name(),
					sent_instruction.opa, sent_instruction.opb,
					actual_flag_vector,expected_flag_vector,actual_result.sign,actual_result.exponent,actual_result.mantissa,
					expected_result_bits[31], expected_result_bits[30:23], expected_result_bits[22:0]);
				
			endcase
			
		end
	
	endfunction
	
	task run();
		
		bit 	eom_flag; 
		bit 	ne_valid; 
		
		while (1)
		begin
			
			//holds the data received from HDL
			//first 4 bytes hold output of fpu operation in reverse byte order
			//last byte holds the flag vector raised by the floating point operation
			//NOTE: the above arrangement depends on the order in which data is sent from HDL side
			automatic byte unsigned data_received[] = new[5];
			
			//receives the data from HDL
			//bytes are sent from HDL in such way that LSByte of the data sent from HDL
			//will be 0th element of data_received, and MSByte will be the last element
			//NOTE: this task is blocking. Waits here until result is available 
			monitorChannel.receive_bytes(1, ne_valid, data_received, eom_flag);
			
			//unpacking the bytes in data_received from right to left order
			//last Byte goes to flag vector
			//remaining bytes, i.e 4 to 1 bytes go to actual_result of type float_t
			//NOTE: this logic depends on the order in which data is sent from HDL
			{actual_flag_vector,actual_result} = { << byte {data_received}};			
			
			//don't compare the results during the initial priming of pipeline
			if (startup <= 5 )
			begin
				startup++;
			end
			else
			begin
				
				//generates the expected result
				generate_expected_result();
				
				//checks the correctness of the expected and obtained results
				//increments the error_count if there is an error
				verify_results();
				
				write_outputs(1);
			end
		
			if(debug)	//Display in debug 
				$display("opa=%f opb=%f Expected result=%f Obtained actual_result =%f",sent_instruction.opa,sent_instruction.opb,expected_result,actual_result);
			
			if(eom_flag)
				$finish;
			
		end	
	endtask

endclass
	

//Stimulus (test) generation class 
//This generates testecases with SV inline randomization 
//To avoid recompilation of the code, user input is taken during vsim command
//invoke. This user input is RUNS and SIGNS. Runs tells how many test cases
//to be generated and Signs tells the sign of the multiplicand and multiplier. 

class stimulus_gen ;

	// handle is driver channel , the handle is to my pipe
	scemi_dynamic_input_pipe 		driverChannel;
	random_instruction				r_instruction;
	
		
	//Constructor
	function new();			
	begin
		// connecting the handle to the input pipe, input pipe is the instance in  hdl
		driverChannel 		= new ("top.inputpipe");
		r_instruction		= new();

		
		//if true, initiates the input file handler
		if(file) 
		begin 	
			
			input_file = $fopen("input.txt","w");			
			$fwrite(input_file,"Inputs given to DUT\n");
		end
		
	end
	endfunction

	//writes the details of generated inputs
	function void write_inputs(bit float_format=1);
		if(file)
		begin
			case (float_format)
								
				0 : $fwrite(input_file,"opcode : %b, rmode : %b,opa : %b, opb : %b \n",
					r_instruction.instruction.fpu_op, r_instruction.instruction.rmode,
					r_instruction.instruction.opa, r_instruction.instruction.opb );
					
				1 : $fwrite(input_file,"opcode : %5s, rmode : %20s,\topa : %20f, \topb : %20f \n",
					r_instruction.instruction.fpu_op.name(), r_instruction.instruction.rmode.name(),
					$bitstoshortreal(r_instruction.instruction.opa), 
					$bitstoshortreal(r_instruction.instruction.opb) );
				
			endcase
			
		end
	endfunction
	
	task run;
		input [31:0]	runs;		
		input [15:0]	signs;
		
		//queue should hold 9 bytes 
		//1 byte for opcode and rounding mode
		//4 bytes for opa + 4 bytes for opb 
		automatic byte unsigned data_send[] = new[9];
		
		//runs number of testcases	wanted to generate	, that no. of cycles
		repeat(runs)		
		begin
	
			assert(r_instruction.randomize())
			else $fatal(0,"(Instruction randomize failed");
			
			sent_queue.push_back(r_instruction.instruction);	
			
			write_inputs();
			
			//packing instruction struct into a queue of bytes
			//0th byte represents {3'b0,3bit opcode,2bit round mode}
			//followed by 4 bytes of opa,
			//followed by 4 bytes of opb
			//total bytes packed = 9 bytes
			//NOTE: this logic depends on the order of memebers in fpu_instruction_t struct
			data_send= {<< byte {3'b0,r_instruction.instruction}};
			
			//filling the input pipe with data_send		
			driverChannel.send_bytes(1, data_send, 0);
			
		end
		
		//when requried number of runs are reached, send eom flag as 1
		data_send[0]=0;
		driverChannel.send_bytes(1,data_send ,1);
		
		//flush the pipe to initiate the processing of data in input pipe
		driverChannel.flush();		
			 
	endtask

endclass


module fpu_hvl;

	scoreboard 		scb;
	stimulus_gen 	stim_gen;
	integer 		runs;
	reg [15:0]		signs;

	task run();			//used fork join done to use
	  integer i;
		fork
		begin
			scb.run();
		end
		join_none
	
		fork			
		begin
			stim_gen.run(runs,signs);
		end			
		join_none
	endtask

	initial 
	fork
	  if($value$plusargs("RUNS=%d",runs))	//is a way to take input
		$display("Generating %d Operands",runs);
				
		scb 		= new();			
		stim_gen 	= new();
		$display("\nStarted at"); $system("date");
		run();
		
		
	join_none

final
begin
	$display("\nEnded at"); $system("date");
	if(!error_count)
	$display("All tests are successful");
	else
	$display("%0d Tests failed out of %0d",error_count,runs);
end
endmodule
 



