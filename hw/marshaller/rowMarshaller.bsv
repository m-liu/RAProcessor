//row marshaller to assemble ddr bursts into table rows


typedef enum { DATA_IO, UNION, DIFFERENCE, SELECTION, PROJECTION, XPROD, DEDUP } ReqSrc deriving (Eq, Bits);
typedef Bit#(32) ROW_BURST;

typedef struct {
	Bit#(32) rowAddr;
	Bit#(16) numRows;
	ReqSrc reqSrc;
} ROW_REQ deriving (Eq,Bits);

interface ROW_ACCESS_IFC;
	method Action rowReq( ROW_REQ req);
	method ActionValue#( ROW_BURST rData ) readResp();
	method Action writeData ( ROW_BURST wData );
endinterface

interface ROW_MARSHALLER_IFC;
	interface Vector(7, ROW_ACCESS_IFC) rowAccesses;
	interface DDR2Client ddrMem;
endinterface

module mkRowMarshaller(ROW_MARSHALLER_IFC);

	FIFO#(DDR2Request) ddrReq <- mkFIFO;
	FIFO#(DDR2Response) ddrResp <- mkFIFO;


	//a vector of interfaces
	Vector(7, ROW_ACCESS_IFC) rowAccesses = newVector();

	for (Integer moduleInd = 0; moduleInd < 7; moduleInd=moduleInd+1) 
	begin
		rowAccesses[moduleInd] =interface ROW_ACCESS_IFC; 
							method Action rowReq ( ROW_REQ req ); 
							endmethod
							
							method ActionValue#( ROW_BURST rData ) readResp();
							endmethod

							method Action writeData ( ROW_BURST wData );
							endmethod

						endinterface
	end

	interface DDR2Client ddrMem;
		interface Get request = toGet(ddrReq);
		interface Put response = toPut(ddrResp);
	endinterface 


endmodule
