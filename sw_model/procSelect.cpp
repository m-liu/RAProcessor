#include <iostream>     
#include <unistd.h>     
#include <cmath>        
#include <cstdio>       
#include <cstdlib>      
#include <string.h>     
#include <stdint.h>     

#include "globalTypes.h"

void doSelect (CmdEntry cmdEntry){

	uint32_t rowBuff[MAX_COLS];
	uint32_t rowAddrOut = 0; 

	for (uint32_t row=0; row < cmdEntry.table0numRows; row++){
		//fill the row buffer
		for (uint32_t col=0; col < cmdEntry.table0numCols; col++){
			rowBuff[col] = globalMem[row][col];
		}
		
		//evaluate all the clauses
		bool qualify[MAX_CLAUSES];
		for (uint32_t cl=0; cl<cmdEntry.numClauses; cl++){
			SelClause clause = cmdEntry.clauses[cl];

			if (clause.clauseType==COL_VAL){
				switch (clause.op) {
					case EQ:
						qualify[cl] = (rowBuff[clause.colOffset0]==clause.val);
						break;
					case LT:
						qualify[cl] = (rowBuff[clause.colOffset0] < clause.val);
						break;
					case LE:
						qualify[cl] = (rowBuff[clause.colOffset0] <= clause.val);
						break;
					case GT:
						qualify[cl] = (rowBuff[clause.colOffset0] > clause.val);
						break;
					case GE:
						qualify[cl] = (rowBuff[clause.colOffset0] >= clause.val);
						break;
					case NE:
						qualify[cl] = (rowBuff[clause.colOffset0] != clause.val);
						break;
					default:
						printf("invalid comparison op\n");
						break;
				}
			}
			else{ //COL_COL
				switch (clause.op) {
					case EQ:
						qualify[cl] = (rowBuff[clause.colOffset0]==rowBuff[clause.colOffset1]);
						break;
					case LT:
						qualify[cl] = (rowBuff[clause.colOffset0] < rowBuff[clause.colOffset1]);
						break;
					case LE:
						qualify[cl] = (rowBuff[clause.colOffset0] <= rowBuff[clause.colOffset1]);
						break;
					case GT:
						qualify[cl] = (rowBuff[clause.colOffset0] > rowBuff[clause.colOffset1]);
						break;
					case GE:
						qualify[cl] = (rowBuff[clause.colOffset0] >= rowBuff[clause.colOffset1]);
						break;
					case NE:
						qualify[cl] = (rowBuff[clause.colOffset0] != rowBuff[clause.colOffset1]);
						break;
					default:
						printf("invalid comparison op\n");
						break;
				}
			}
		}

		//remap the qualify array such that we have 4 literals of 4 disjunctions
		//KEY ASSUMPTION: 16 predicates, in disjunctive normal form with 4 disjunctions per literal, and 4 literals
		bool qualify_remap[MAX_OR_CLAUSES][MAX_AND_CLAUSES];
		//initialize to 0111 0111 0111 0111
		for (int i=0; i<MAX_OR_CLAUSES; i++){
			for (int j=0; j<MAX_AND_CLAUSES; j++){
				if (j==0){
					qualify_remap[i][j] = false;
				} else {
					qualify_remap[i][j] = true;
				}
			}
		}

		uint32_t orInd=0, andInd=0;

		for (uint32_t n=0; n < cmdEntry.numClauses; n++){
			if (n==0){
				//always fill in the first one
				qualify_remap[orInd][andInd] = qualify[n]; 
				andInd++;
			}
			
			else if (cmdEntry.con[n-1] == AND){
				qualify_remap[orInd][andInd] = qualify[n];
				andInd++;
			}
			else if (cmdEntry.con[n-1] == OR){
				orInd++;
				andInd=0;
				qualify_remap[orInd][andInd] = qualify[n];
				andInd++;
			}

		}
	
		//Evaluate
		bool qualify_tmp;
		bool accept = false;
		for (int i=0; i<MAX_OR_CLAUSES; i++){
			qualify_tmp = true;
			for (int j=0; j<MAX_AND_CLAUSES; j++){
				qualify_tmp = (qualify_tmp && qualify_remap[i][j]);
			}
			accept = (accept || qualify_tmp);
		}

		//If accept, store it back to memory starting at outputAddr
		uint32_t addr;
		if (accept) {
			addr = cmdEntry.outputAddr + rowAddrOut;
			rowAddrOut++;
			for (uint32_t col=0; col < cmdEntry.table0numCols; col++){
				globalMem[addr][col] = rowBuff[col];
			}
		}

	}

	//TODO update the command buffer with information on how many rows were selected
	//TODO map the clauses to the evaluators in software!
}
