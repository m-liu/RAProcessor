#!/usr/bin/perl
use warnings;

$num_args = $#ARGV+1;
if ($num_args != 1) {
	print "enter table name\n";
	exit;
}

my $tableName = $ARGV[0]; 
print "creating table $tableName\n";
my $fileName = $tableName.".csv";
my $fileNameTxt = $tableName.".txt";

if (-e $fileName) {
	print "file exists, exiting..";
	exit;
}
open(GAS1, ">$fileName") or die $!;
open(GAS1TXT, ">$fileNameTxt") or die $!;

#print header
print GAS1 "$tableName\n";
print GAS1 "iOrder, element, phi, age, color, planet, galaxy\n";

#random number of rows between 100 to 200-1
my $minRows = 50;
my $numRows = int(rand(50)) + $minRows;

for ($r=0; $r<$numRows; $r++){
	my $iOrder = $r;
	my $element = int(rand(4));
	my $phi = int(rand(30));
	my $age = int(rand(10000000));
	my $color = int(rand(10));
	my $planet = int(rand(5000));
	my $galaxy = int(rand(3));
	
	print GAS1 "$iOrder, $element, $phi, $age, $color, $planet, $galaxy\n";
	print GAS1TXT "$iOrder, $element, $phi, $age, $color, $planet, $galaxy\n";

}

close(GAS1);
close(GAS1TXT);

