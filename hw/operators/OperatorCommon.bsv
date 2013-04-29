
import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import RowMarshaller::*;
import ControllerTypes::*;

//TODO side interface to other operators


interface OPERATOR_IFC;
	interface ROW_ACCESS_CLIENT_IFC rowIfc;
	interface CMD_SERVER_IFC cmdIfc;
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


