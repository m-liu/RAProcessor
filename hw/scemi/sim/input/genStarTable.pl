#!/usr/bin/perl
use warnings;

$num_args = $#ARGV+1;
if ($num_args != 1) {
	print "enter table name\n";
	exit;
}

my $tableName = $ARGV[0]; 
print "creating table $tableName\n";
my $fileName = "input/".$tableName.".csv";
my $fileNameTxt = "input/".$tableName.".txt";
open(STAR1, ">$fileName") or die $!;
open(STAR1TXT, ">$fileNameTxt") or die $!;

#print header
print STAR1 "$tableName\n";
print STAR1 "iOrder, mass, pos_x, pos_y, pos_z, vx, vy, vz, phi, metals, tform, eps\n";

#random number of rows between 100 to 200-1
my $minRows = 10;
my $numRows = int(rand(30)) + $minRows;

for ($r=0; $r<$numRows; $r++){
	my $iOrder = $r;
	my $mass = int(rand(100000));
	my $pos_x = int(rand(50));
	my $pos_y = int(rand(50));
	my $pos_z = int(rand(50));
	my $vx = int(rand(1000));
	my $vy = int(rand(1000));
	my $vz = int(rand(1000));
	my $phi = int(rand(5));
	my $metals = int(rand(2));
	my $tform = int(rand(30));
	my $eps = int(rand(200000));

	print STAR1 "$iOrder, $mass, $pos_x, $pos_y, $pos_z, $vx, $vy, $vz, $phi, $metals, $tform, $eps\n";
	print STAR1TXT "$iOrder, $mass, $pos_x, $pos_y, $pos_z, $vx, $vy, $vz, $phi, $metals, $tform, $eps\n";

}

close(STAR1);
close(STAR1TXT);

