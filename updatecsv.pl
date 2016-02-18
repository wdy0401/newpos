#!/usr/bin/perl -w 
use Getopt::Long;
use FindBin qw($Bin);
use 5.010;

my $exchg="sq";

GetOptions(
    "exchg=s"  => \$exchg,
);

my (@days)=&getdays();
for my $dt(@days)
{
	next if $dt<20100416 and $exchg eq 'zj';
	next if $dt<20020107 and $exchg eq 'sq';
	next if $dt<20010508 and $exchg eq 'ds';
	next if $dt<20050429 and $exchg eq 'zs';
	system("perl download_from_exchange.pl -date $dt -exchg $exchg")
}
print STDERR "No update needed\n" unless @days;

sub getdays()
{
	my $today=gettoday();
	my $ld;
	if (-s "$Bin/$exchg/sqlfile/volume.csv")
	{
		$ld=`perl c:/code/file_backward.pl -file  $Bin/$exchg/sqlfile/volume.csv -n 2`;
		($ld)=($ld=~/(\d{8})/);
		$ld+=0;
	}
	else{$ld=0;}
	#$ld=20140200;
	my $lastday=(split/,/,$ld)[0];
	
	my @days;
	open(IN,"c:/code/bizd.txt");
	while(<IN>)
	{
		s/\s+//;
		push @days,$_ if $_>$lastday and $_<=$today;
	}
	close IN;
	print STDERR "UPDATE DAYS :\n@days\n";
	return @days;
}
sub gettoday()
{
	my @today=localtime(time);
	$td=$today[3]+100*($today[4]+1)+10000*($today[5]+1900);
	return $td;
}


