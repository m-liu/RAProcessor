DROP TABLE star1;
DROP TABLE star2;
DROP TABLE star3;
DROP TABLE star4;
DROP TABLE gas1;
DROP TABLE gas2;
DROP TABLE gas3;

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


CREATE TABLE gas1 (
    iOrder  integer PRIMARY KEY, 
    element integer, 
    phi     integer, 
    age     integer, 
    color   integer,
    planet  integer,
    galaxy  integer
);


CREATE TABLE gas2 (
    iOrder  integer PRIMARY KEY, 
    element integer, 
    phi     integer, 
    age     integer, 
    color   integer,
    planet  integer,
    galaxy  integer
);


CREATE TABLE gas3 (
    iOrder  integer PRIMARY KEY, 
    element integer, 
    phi     integer, 
    age     integer, 
    color   integer,
    planet  integer,
    galaxy  integer
);



-- COPY star1 from '../sw_model/input/star1.csv' DELIMITERS ',' CSV;

-- mass import csv into sqlite:
-- .separator ","
-- .import <path to csv> <table name> 
.separator ","
.import ../hw/scemi/sim/input/star1.txt star1 
.import ../hw/scemi/sim/input/star2.txt star2 
.import ../hw/scemi/sim/input/star3.txt star3 
.import ../hw/scemi/sim/input/star4.txt star4 
.import ../hw/scemi/sim/input/gas1.txt gas1 
.import ../hw/scemi/sim/input/gas2.txt gas2 
.import ../hw/scemi/sim/input/gas3.txt gas3 
