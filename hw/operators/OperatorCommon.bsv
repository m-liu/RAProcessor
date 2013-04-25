
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
	method Action pushCommand (CmdEntry cmdEntry);
	method ActionValue#( RowAddr ) getAckRows();
endinterface

