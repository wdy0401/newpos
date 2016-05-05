#!/usr/bin/perl -w 
use Getopt::Long;
use FindBin qw($Bin);
use 5.010;
use File::Path qw(make_path remove_tree);

my $exchg="sq";

GetOptions(
    "exchg=s"  => \$exchg,
);
my $dir="$Bin/$exchg/sqlfile";
mkdir $dir unless -d $dir; 
my (@days)=&getdays();

open(OUTV," >> $dir/volume.csv") or die "Cannot open volumefile $dir/volume.csv";
open(OUTL," >> $dir/long.csv") or die "Cannot open longfile $dir/long.csv";
open(OUTS," >> $dir/short.csv") or die "Cannot open shortfile $dir/shotr.csv";
for my $dt(@days)
{
	my $file="$Bin/$exchg/files/${dt}_pos.csv";

	next if $dt<20100416 and $exchg eq 'zj';
	next if $dt<20020107 and $exchg eq 'sq';
	next if $dt<20010508 and $exchg eq 'ds';
	next if $dt<20050429 and $exchg eq 'zs';
	if(! -s $file)
	{
		warn "Cannot open file $file\n";
		next;
	}
	open(IN,"$file") or die "Open file error $file\n";
	my ($year)=($dt=~/^(\d{4})/);
	make_path "$dir/vol/$year" unless -d "$dir/vol/$year";
	#print"$dir/vol/$year\n";exit;
	make_path "$dir/long/$year" unless -d "$dir/long/$year";
	make_path "$dir/short/$year" unless -d "$dir/short/$year";
	
	print "gen dbfile date $dt\n";
	open(OUTVD," > $dir/vol/$year/${dt}.csv") or die "Cannot open volfile $dt\n";
	open(OUTLD," > $dir/long/$year/${dt}.csv") or die "Cannot open longfile $dt\n";
	open(OUTSD," > $dir/short/$year/${dt}.csv") or die "Cannot open shortfile $dt\n";
	while(<IN>)
	{
		print OUTV $_ if /,成交,/;
		print OUTVD $_ if /,成交,/;
		print OUTL $_ if /,多,/;
		print OUTLD $_ if /,多,/;
		print OUTS $_ if /,空,/;
		print OUTSD $_ if /,空,/;
	}
	close IN;
	close OUTVD;
	close OUTLD;
	close OUTSD;
}
close OUTV;
close OUTL;
close OUTS;
print STDERR "No update needed pos\n" unless @days;
&checkdbfile();

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
sub checkdbfile()
{
	for my $dt (@days)
	{
		for my $f(qw!vol long short!)
		{
			my ($year)=($dt=~/^(\d{4})/);
			my $file= "$dir/$f/$year/${dt}.csv";
			if(!-s $file){warn "DB file error found $file\n";next;}
			open(IN," $file");
			while(<IN>)
			{
				next unless $_;
				my @a=(split/,/);
				die "DB file error count $file @a\n" if scalar @a != 7;
				die "DB file error seq $file @a\n" if scalar $a[3]!~/^\d+$/;			
			}
			close IN;
			print "DB file checked $file\n";
		}
	}
	
}