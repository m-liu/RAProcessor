// Generate a set of structs of commands to be passed to the RA processor
// Parses an input file of RA operators



#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string.h>

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
	printf("ERROR: cannot find table %s in metadata\n");
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
    int offset = 0;

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
    printf("cmdEntry.table0Addr=%d\n", cmdEntry.table0Addr);
    printf("cmdEntry.table0numRows=%d\n", cmdEntry.table0numRows);
    printf("cmdEntry.table0numCols=%d\n", cmdEntry.table0numCols);
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
        printf("colOffset0:%d, op:%d, val:%d, colOffset1:%d\n", cl.colOffset0, cl.op, 
				cl.val, cl.colOffset1);
        if (c < cmdEntry.numClauses-1) {
			if (cmdEntry.con[c] == AND) {
	            printf("clausecon %d: AND\n", c);
			} else if (cmdEntry.con[c] == OR) {
	            printf("clausecon %d: OR\n", c);
			}
        }
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

    globalNextMeta++;
    globalNextAddr = globalNextAddr + tableMeta.numRows; 


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
    
    cmdEntry.op = SELECT;
    cmdEntry.table0Addr = tableMeta.startAddr;
    cmdEntry.table0numRows = tableMeta.numRows;
    cmdEntry.table0numCols = tableMeta.numCols;

	dumpCmdEntry (cmdEntry);
    return cmdEntry;
}

CmdEntry parseProject (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing PROJECT...\n");
    CmdEntry cmdEntry;
    TableMetaEntry tableMeta = findTableMetadata(cmdTokens[1]);
	uint32_t mask = 0; 

	/*
	//look up all the column names, and convert them to a one-hot encoding mask
	while (ntok < numTokens) {
		

	}*/


	//TODO this assumes largest possible table size as output
	
	
}

CmdEntry parseUnion (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing UNION...\n");
    CmdEntry cmdEntry;
}

CmdEntry parseDifference (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing DIFFERENCE...\n");
}


CmdEntry parseXprod (char cmdTokens[][MAX_CHARS], int numTokens){
    printf("parsing XPROD...\n");
}





//************************************************************
// genCommand produces and returns  the final command struct
//************************************************************


//CmdOp genCommand () {
void genCommand() {
    FILE *cmdFile = fopen("input/commands.txt", "r"); 
    char cmdLine[MAX_CHARS];
    char cmdTokens[MAX_CMD_TOKENS][MAX_CHARS];
    char op[MAX_CHARS];
    char *pch; 
    int i=0;
    int numTokens=0;

    if (cmdFile==NULL) {
        perror("error opening command file"); 
    }

    while( fgets(cmdLine, MAX_CHARS, cmdFile) != NULL ) {

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
            parseSelect(cmdTokens, numTokens);
        }
        else if (strcmp(op, "PROJECT") == 0){
            parseProject(cmdTokens, numTokens);
        }
        else if (strcmp(op, "XPROD") == 0){
            parseXprod(cmdTokens, numTokens);
        }
        else if (strcmp(op, "UNION") == 0){
            parseUnion(cmdTokens, numTokens);
        }
        else if (strcmp(op, "DIFFERENCE") == 0){
            parseDifference(cmdTokens, numTokens);
        }
        else {
            perror("Error: invalid op\n");
        }


    }

    fclose(cmdFile); 
}





