SOURCES=genCommand.cpp tableParser.cpp procTop.cpp globalTypes.cpp procModel.cpp procProject.cpp procSelect.cpp procUnionDiffXprod.cpp procDedup.cpp
EXECUTABLE=runProc

CC=g++
CFLAGS=-c -Wall -g
LDFLAGS=

BuildDir=build/

OBJECTS=$(SOURCES:.cpp=.o)
COBJECTS=$(addprefix $(BuildDir), $(OBJECTS))

all: $(SOURCES) $(EXECUTABLE)
		
$(EXECUTABLE): $(COBJECTS) 
		$(CC) $(LDFLAGS) $(COBJECTS) -o $@

$(BuildDir)%.o: %.cpp
		$(CC) $(CFLAGS) $< -o $@


clean: 
	rm -rf $(COBJECTS) runProc
