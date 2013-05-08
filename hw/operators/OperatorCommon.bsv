
import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import RowMarshaller::*;
import ControllerTypes::*;

//TODO side interface to other operators

//TODO remove this
interface OPERATOR_IFC;
	interface ROW_ACCESS_CLIENT_IFC rowIfc;
	interface CMD_SERVER_IFC cmdIfc;
endinterface

interface UNARY_OPERATOR_IFC;
	interface ROW_ACCESS_CLIENT_IFC rowIfc;
	interface CMD_SERVER_IFC cmdIfc;
	//side interfaces to other operators. 4 from binary ops, 1 to other unary op
	interface INTEROP_SERVER_IFC interOutIfc;
	interface Vector#(4, INTEROP_CLIENT_IFC) interInIfc;
endinterface

interface BINARY_OPERATOR_IFC;
	interface ROW_ACCESS_CLIENT_IFC rowIfc;
	interface CMD_SERVER_IFC cmdIfc;
	//side interfaces to other operators. 2 to unary ops
	interface Vector#(2, INTEROP_SERVER_IFC) interOutIfc;
endinterface


interface CMD_SERVER_IFC;
	method Action pushCommand (CmdEntry cmdEntry);
	method ActionValue#( RowAddr ) getAckRows();
endinterface

interface CMD_CLIENT_IFC;
	method ActionValue#(CmdEntry) pushCommand ();
	method Action getAckRows( RowAddr nRows );
endinterface

instance Connectable#(CMD_SERVER_IFC, CMD_CLIENT_IFC);
	module mkConnection#(CMD_SERVER_IFC serv, CMD_CLIENT_IFC cli) (Empty);
		mkConnection(serv.pushCommand, cli.pushCommand);
		mkConnection(serv.getAckRows, cli.getAckRows);
	endmodule
endinstance

interface INTEROP_SERVER_IFC;
	method ActionValue#(RowBurst) readResp();
endinterface

interface INTEROP_CLIENT_IFC;
	method Action readResp(RowBurst rData);
endinterface

instance Connectable#(INTEROP_SERVER_IFC, INTEROP_CLIENT_IFC);
	module mkConnection#(INTEROP_SERVER_IFC serv, INTEROP_CLIENT_IFC cli) (Empty);
		mkConnection(cli.readResp, serv.readResp);
	endmodule
endinstance
