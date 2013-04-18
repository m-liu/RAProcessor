// Generate a set of structs of commands to be passed to the RA processor
// Parses an input file of RA operators



#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string.h>
#include <assert.h>
#include <stdint.h> 

#include "globalTypes.h"
#include "genCommand.h"

#define MAX_CMD_TOKENS 64

using namespace std;

//extern uint32_t **globalMem;
//extern TableMetaEntry globalTableMeta;

//****************************************
// Helper functions
//****************************************
TableMetaEntry findTableMetadata (char *tableName) {
    for (int i=0; i<MAX_TABLES; i++){
        if ( strncmp(globalTableMeta[i].tableName, tableName, MAX_CHARS) == 0 ){
            return globalTableMeta[i];
        }
    }
	printf("ERROR: cannot find table %s in metadata\n", tableName);
	exit (EXIT_FAILURE);
}

uint32_t findTableMetadataInd (char *tableName) {
    for (int i=0; i<MAX_TABLES; i++){
        if ( strncmp(globalTableMeta[i].tableName, tableName, MAX_CHARS) == 0 ){
            return i;
        }
    }
	printf("ERROR: cannot find table %s in metadata\n", tableName);
	exit (EXIT_FAILURE);
}


uint32_t getColOffset (char *col, TableMetaEntry tableMeta){
	for ( uint32_t offset=0; offset<MAX_COLS; offset++ ) {
		if ( strcmp(tableMeta.colNames[offset], col) == 0 ) {
			return offset;
		}
	}
    printf("ERROR: can't find column named: %s\n", col);
	exit (EXIT_FAILURE);
}

SelClause getClause (char *col1, char *op, char *col2_or_val, TableMetaEntry tableMeta) {
    SelClause clause;
    long int val;
    char *pEnd;

    //fill in the common stuff
	clause.colOffset0 = getColOffset(col1, tableMeta);

    if ( strcmp(op, "=") == 0 )
        clause.op = EQ;
    else if (strcmp(op, "<") == 0)
        clause.op = LT;
    else if (strcmp(op, "<=") == 0)
        clause.op = LE;
    else if (strcmp(op, ">") == 0)
        clause.op = GT;
    else if (strcmp(op, ">=") == 0)
        clause.op = GE;
    else if (strcmp(op, "!=") == 0)
        clause.op = NE;
    else
        perror("ERROR: Invalid comparison operator");

    val = strtol(col2_or_val, &pEnd, 10); 
    if (! *pEnd) { //conversion to int successful. this is a col CMP val type clause
        clause.clauseType = COL_VAL;
        clause.val = val;
		clause.colOffset1=0;
    }
    else { //a col CMP col type clause
        clause.clauseType = COL_COL;
		clause.val = 0;
		clause.colOffset1 = getColOffset(col2_or_val, tableMeta);
    }

    return clause;
}


//print all of the table metadatas
void dumpTableMetas(){
	printf("\nDumping table metadata...\n");
	for (uint32_t i=0; i<globalNextMeta; i++){
		TableMetaEntry entry = globalTableMeta[i];
		printf("\t-------------\n");
		printf("\tTable #%d: %s\n", i, entry.tableName);
		printf ("\t%d rows x %d cols @ addr %d\n\t", entry.numRows, entry.numCols, entry.startAddr);
		for (uint32_t j=0; j< entry.numCols; j++){
			printf("| %s ", entry.colNames[j]);
		}
		printf("\n");
	}
}





void dumpCmdEntry (CmdEntry cmdEntry){
    printf("\ncmdEntry.op=%d\n", cmdEntry.op);
    printf("cmdEntry 1st input table: %d rows x %d cols @ addr=%d\n", cmdEntry.table0numRows, cmdEntry.table0numCols, cmdEntry.table0Addr);
	printf("cmdEntry output table addr=%d\n", cmdEntry.outputAddr);

	if (cmdEntry.op == SELECT){
		printf("---SELECT---\n");
		for (uint32_t c=0; c<cmdEntry.numClauses; c++){
			SelClause cl = cmdEntry.clauses[c];
			printf("clause %d: ", c);
			if (cl.clauseType==COL_COL){
				printf("type: COL_COL "); 
			}
			else if (cl.clauseType==COL_VAL){
				printf("type: COL_VAL ");
			}	
			printf("colOffset0:%d, op:%d, val:%lu, colOffset1:%d\n", cl.colOffset0, cl.op, 
					cl.val, cl.colOffset1);
			if (c < cmdEntry.numClauses-1) {
				if (cmdEntry.con[c] == AND) {
					printf("clausecon %d: AND\n", c);
				} else if (cmdEntry.con[c] == OR) {
					printf("clausecon %d: OR\n", c);
				}
			}
		}
	}
	else if (cmdEntry.op == PROJECT){
		printf("---PROJECT---\n");
		printf("projectMask = %x\n", cmdEntry.colProjectMask);
	}
	else if (cmdEntry.op == UNION || cmdEntry.op == DIFFERENCE || cmdEntry.op == XPROD){
		printf("---UNION/DIFF/XPROD---\n");
    	printf("cmdEntry 2nd input table: %d rows x %d cols @ addr=%d\n", cmdEntry.table1numRows, cmdEntry.table1numCols, cmdEntry.table1Addr);
	}

	printf("------------------------\n\n");
}



//****************************************
// Parsers to parse each operator command
//****************************************

CmdEntry parseSelect (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing SELECT...\n");
    CmdEntry cmdEntry;

    //find the metadata of the input table
    TableMetaEntry tableMeta = findTableMetadata(cmdTokens[1]);
    //TODO what to do with the output table?
    //TODO this is not an optimal solution. Assumes the filter result has the same number of rows as the input
    //insert a new entry into the globalTableMeta
    globalTableMeta[globalNextMeta] = tableMeta; //use input as base
    strcpy( globalTableMeta[globalNextMeta].tableName, cmdTokens[2] );
    globalTableMeta[globalNextMeta].startAddr = globalNextAddr;
	
    int c=0;
    int ntok=3; //parse the clauses, start at ind=3

    while (ntok < numTokens){
        //3 tokens per clause + 1 optional connecting AND/OR
        cmdEntry.clauses[c] = getClause(cmdTokens[ntok], cmdTokens[ntok+1], cmdTokens[ntok+2], tableMeta);
        ntok = ntok+3;
        if (ntok < numTokens) {
            if ( strcmp(cmdTokens[ntok], "AND") == 0 ) {
                cmdEntry.con[c] = AND;
            }
            else if (strcmp(cmdTokens[ntok], "OR") == 0) {
                cmdEntry.con[c] = OR;
            }
            else {
                printf("ERROR: invalid clause connecting phrase: %s\n", cmdTokens[ntok]);
				exit (EXIT_FAILURE);
            }
            ntok++;
        }
        c++;
    }

    cmdEntry.numClauses=c;
	cmdEntry.outputAddr = globalTableMeta[globalNextMeta].startAddr;
    cmdEntry.op = SELECT;
    cmdEntry.table0Addr = tableMeta.startAddr;
    cmdEntry.table0numRows = tableMeta.numRows;
    cmdEntry.table0numCols = tableMeta.numCols;

	//increment global pointers
	globalNextAddr = globalNextAddr + globalTableMeta[globalNextMeta].numRows;
    globalNextMeta++;

	//dumpCmdEntry (cmdEntry);
    return cmdEntry;
}

CmdEntry parseProject (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing PROJECT...\n");
    CmdEntry cmdEntry;
 
 	TableMetaEntry tableMeta = findTableMetadata(cmdTokens[1]);

	//Output table metadata
	//TODO this assumes largest possible table size as output
    globalTableMeta[globalNextMeta] = tableMeta; //use input as base
    strcpy( globalTableMeta[globalNextMeta].tableName, cmdTokens[2] );
    globalTableMeta[globalNextMeta].startAddr = globalNextAddr;
	
	uint32_t mask = 0; 
	int ntok = 3;
	uint32_t colOffset=0;
	uint32_t c=0; 
	
	//look up all the column names, and convert them to a one-hot encoding mask
	while (ntok < numTokens) {
		colOffset=getColOffset(cmdTokens[ntok], tableMeta);
		assert(colOffset < MAX_COLS);
		mask = mask | (1<<colOffset);

		//update metadata: column names and numCols have changed
		strcpy(globalTableMeta[globalNextMeta].colNames[colOffset], cmdTokens[ntok]);
		c++;
		ntok++;
	}
	//compact the column names
	uint32_t mask_tmp = mask;
	uint32_t newInd = 0;
	for (int i=0; i< MAX_COLS; i++){
		if ( (mask_tmp & 0x1) == 1){
			strcpy(globalTableMeta[globalNextMeta].colNames[newInd], globalTableMeta[globalNextMeta].colNames[i]);
			newInd++;
		}
		mask_tmp = mask_tmp >> 1;
	}

	//update numCols
	globalTableMeta[globalNextMeta].numCols = c;

	cmdEntry.outputAddr = globalTableMeta[globalNextMeta].startAddr;
	cmdEntry.colProjectMask = mask;
	cmdEntry.op = PROJECT;
    cmdEntry.table0Addr = tableMeta.startAddr;
    cmdEntry.table0numRows = tableMeta.numRows;
    cmdEntry.table0numCols = tableMeta.numCols;
	
	//update global pointers TODO make these functions
	globalNextAddr = globalNextAddr + globalTableMeta[globalNextMeta].numRows;
    globalNextMeta++;
	
	//dumpCmdEntry (cmdEntry);
	return cmdEntry;
	
}

CmdEntry parseUnion (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing UNION...\n");
    CmdEntry cmdEntry;
 	
	TableMetaEntry tableMeta0 = findTableMetadata(cmdTokens[1]);
	TableMetaEntry tableMeta1 = findTableMetadata(cmdTokens[2]);

	//output table metadata
	globalTableMeta[globalNextMeta] = tableMeta0; //use as base
    strcpy( globalTableMeta[globalNextMeta].tableName, cmdTokens[3] );
	globalTableMeta[globalNextMeta].startAddr = globalNextAddr;
	//# rows is sum of both (worst case)
	globalTableMeta[globalNextMeta].numRows = tableMeta0.numRows + tableMeta1.numRows; 
	
	cmdEntry.outputAddr = globalTableMeta[globalNextMeta].startAddr;
	cmdEntry.op = UNION;
    cmdEntry.table0Addr = tableMeta0.startAddr;
    cmdEntry.table0numRows = tableMeta0.numRows;
    cmdEntry.table0numCols = tableMeta0.numCols;
    cmdEntry.table1Addr = tableMeta1.startAddr;
    cmdEntry.table1numRows = tableMeta1.numRows;
    cmdEntry.table1numCols = tableMeta1.numCols;

	//increment global pointers
	globalNextAddr = globalNextAddr + globalTableMeta[globalNextMeta].numRows;
	globalNextMeta++;
	
	//dumpCmdEntry (cmdEntry);
	return cmdEntry;

}

CmdEntry parseDifference (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing DIFFERENCE...\n");
    CmdEntry cmdEntry;

	TableMetaEntry tableMeta0 = findTableMetadata(cmdTokens[1]);
	TableMetaEntry tableMeta1 = findTableMetadata(cmdTokens[2]);

	//output table metadata
	//# rows is at most the num of rows in table0 (worst case)
	globalTableMeta[globalNextMeta] = tableMeta0; //use as base
    strcpy( globalTableMeta[globalNextMeta].tableName, cmdTokens[3] );
	globalTableMeta[globalNextMeta].startAddr = globalNextAddr;
	
	cmdEntry.outputAddr = globalTableMeta[globalNextMeta].startAddr;
	cmdEntry.op = DIFFERENCE;
    cmdEntry.table0Addr = tableMeta0.startAddr;
    cmdEntry.table0numRows = tableMeta0.numRows;
    cmdEntry.table0numCols = tableMeta0.numCols;
    cmdEntry.table1Addr = tableMeta1.startAddr;
    cmdEntry.table1numRows = tableMeta1.numRows;
    cmdEntry.table1numCols = tableMeta1.numCols;

	//increment global pointers
	globalNextAddr = globalNextAddr + globalTableMeta[globalNextMeta].numRows;
	globalNextMeta++;
	
	//dumpCmdEntry (cmdEntry);
	return cmdEntry;
}


CmdEntry parseXprod (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing XPROD...\n");
    CmdEntry cmdEntry;

	TableMetaEntry tableMeta0 = findTableMetadata(cmdTokens[1]);
	TableMetaEntry tableMeta1 = findTableMetadata(cmdTokens[2]);

	//output table metadata
	globalTableMeta[globalNextMeta] = tableMeta0; //use as base
    strcpy( globalTableMeta[globalNextMeta].tableName, cmdTokens[3] );
	globalTableMeta[globalNextMeta].startAddr = globalNextAddr;
	//# rows is at most the nrows table0 x nrows table1 (worst case)
	globalTableMeta[globalNextMeta].numRows = tableMeta0.numRows * tableMeta1.numRows;
	//# cols is ncols table0 + ncols table1
	globalTableMeta[globalNextMeta].numCols = tableMeta0.numCols + tableMeta1.numCols;
	//append table1's column names
	for(uint32_t i=0; i<tableMeta1.numCols; i++){
		strcpy( globalTableMeta[globalNextMeta].colNames[i+tableMeta0.numCols], tableMeta1.colNames[i] );
	}

	
	cmdEntry.outputAddr = globalTableMeta[globalNextMeta].startAddr;
	cmdEntry.op = XPROD;
    cmdEntry.table0Addr = tableMeta0.startAddr;
    cmdEntry.table0numRows = tableMeta0.numRows;
    cmdEntry.table0numCols = tableMeta0.numCols;
    cmdEntry.table1Addr = tableMeta1.startAddr;
    cmdEntry.table1numRows = tableMeta1.numRows;
    cmdEntry.table1numCols = tableMeta1.numCols;

	//increment global pointers
	globalNextAddr = globalNextAddr + globalTableMeta[globalNextMeta].numRows;
	globalNextMeta++;
	
	//dumpCmdEntry (cmdEntry);
	return cmdEntry;
}


CmdEntry parseDedup (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing DEDUP...\n");
    CmdEntry cmdEntry;

	TableMetaEntry tableMeta0 = findTableMetadata(cmdTokens[1]);

	//Output table metadata; rows/cols the same as input table (worst case)
	globalTableMeta[globalNextMeta] = tableMeta0; //use as base
    strcpy( globalTableMeta[globalNextMeta].tableName, cmdTokens[2] );
	globalTableMeta[globalNextMeta].startAddr = globalNextAddr;

	
	cmdEntry.outputAddr = globalTableMeta[globalNextMeta].startAddr;
	cmdEntry.op = DEDUP;
    cmdEntry.table0Addr = tableMeta0.startAddr;
    cmdEntry.table0numRows = tableMeta0.numRows;
    cmdEntry.table0numCols = tableMeta0.numCols;


	//increment global pointers
	globalNextAddr = globalNextAddr + globalTableMeta[globalNextMeta].numRows;
	globalNextMeta++;

	return cmdEntry;

}

void parseRename (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing RENAME...\n");
	
	uint32_t tableMetaInd = findTableMetadataInd(cmdTokens[1]);
	for (int i=2; i< numTokens; i=i+2){
		int colInd = atoi(cmdTokens[i]);
		if (colInd < (int)globalTableMeta[tableMetaInd].numCols) {
			strcpy(globalTableMeta[tableMetaInd].colNames[colInd],cmdTokens[i+1]);
		}
		else {
			printf("RENAME: column index out of bound. Table %s has %d cols\n", globalTableMeta[tableMetaInd].tableName, globalTableMeta[tableMetaInd].numCols);
			exit(EXIT_FAILURE);
		}
	}
}


//************************************************************
// genCommand produces and returns  the final command struct
//************************************************************

//returns how many commands it got
uint32_t genCommand(const char *cmdFilePath, CmdEntry *cmdEntryBuff) {
    FILE *cmdFile = fopen(cmdFilePath, "r"); 
    char cmdLine[MAX_CHARS];
    char cmdTokens[MAX_CMD_TOKENS][MAX_CHARS];
    char op[MAX_CHARS];
    char *pch; 
    int i=0;
    int numTokens=0;
	int cmdInd=0;

    if (cmdFile==NULL) {
        perror("error opening command file"); 
    }

    while( fgets(cmdLine, MAX_CHARS, cmdFile) != NULL ) {
		assert (cmdInd < MAX_NUM_CMDS);

        i=0;
        //get rid of \n in cmdLine
        size_t ln = strlen(cmdLine) - 1;
        if (cmdLine[ln] == '\n')
                cmdLine[ln] = '\0';
        
        //tokenize cmd
        pch = strtok(cmdLine, ","); 
        strcpy(op,pch);

        printf("tokens: ");
        while (pch != NULL){
            strcpy(cmdTokens[i], pch);
            printf("%s | ", cmdTokens[i]);
            pch = strtok (NULL, ","); 
            i++;
        }
        numTokens = i;
        printf("\n");
        
        //parse each command based on the op
        if (strcmp(op, "SELECT") == 0){
            cmdEntryBuff[cmdInd] = parseSelect(cmdTokens, numTokens);
        }
        else if (strcmp(op, "PROJECT") == 0){
            cmdEntryBuff[cmdInd] = parseProject(cmdTokens, numTokens);
        }
        else if (strcmp(op, "XPROD") == 0){
            cmdEntryBuff[cmdInd] = parseXprod(cmdTokens, numTokens);
        }
        else if (strcmp(op, "UNION") == 0){
            cmdEntryBuff[cmdInd] = parseUnion(cmdTokens, numTokens);
        }
        else if (strcmp(op, "DIFFERENCE") == 0){
            cmdEntryBuff[cmdInd] = parseDifference(cmdTokens, numTokens);
        }
		else if (strcmp(op, "DEDUP") == 0){
            cmdEntryBuff[cmdInd] = parseDedup(cmdTokens, numTokens);
		}
		else if (strcmp(op, "RENAME") == 0){ //Not a command to the RA proc, just metadata change
            parseRename(cmdTokens, numTokens);
			cmdInd--; //do not increment cmdInd
		}
        else {
            perror("Error: invalid op\n");
        }
		
		cmdInd++;

    }

    fclose(cmdFile); 
	printf("done genCommand\n");

	return cmdInd;
}





