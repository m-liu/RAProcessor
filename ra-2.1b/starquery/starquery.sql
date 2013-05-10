DROP TABLE star1;
DROP TABLE star2;
DROP TABLE star3;
DROP TABLE star4;

CREATE TABLE star1 (
    iOrder  integer PRIMARY KEY, 
    mass    integer, 
    pos_x   integer, 
    pos_y   integer, 
    pos_z   integer,
    vx      integer,
    vy      integer,
    vz      integer, 
    phi     integer,
    metals  integer,
    tform   integer,
    eps     integer
);

CREATE TABLE star2 (
    iOrder  integer PRIMARY KEY, 
    mass    integer, 
    pos_x   integer, 
    pos_y   integer, 
    pos_z   integer,
    vx      integer,
    vy      integer,
    vz      integer, 
    phi     integer,
    metals  integer,
    tform   integer,
    eps     integer
);

CREATE TABLE star3 (
    iOrder  integer PRIMARY KEY, 
    mass    integer, 
    pos_x   integer, 
    pos_y   integer, 
    pos_z   integer,
    vx      integer,
    vy      integer,
    vz      integer, 
    phi     integer,
    metals  integer,
    tform   integer,
    eps     integer
);

CREATE TABLE star4 (
    iOrder  integer PRIMARY KEY, 
    mass    integer, 
    pos_x   integer, 
    pos_y   integer, 
    pos_z   integer,
    vx      integer,
    vy      integer,
    vz      integer, 
    phi     integer,
    metals  integer,
    tform   integer,
    eps     integer
);

-- COPY star1 from '../sw_model/input/star1.csv' DELIMITERS ',' CSV;

-- mass import csv into sqlite:
-- .separator ","
-- .import <path to csv> <table name> 
.separator ","
~/RAProcessor/hw/scemi/sim/input
.import ../hw/scemi/sim/input/star1.txt star1 
.import ../hw/scemi/sim/input/star2.txt star2 
.import ../hw/scemi/sim/input/star3.txt star3 
.import ../hw/scemi/sim/input/star4.txt star4 
