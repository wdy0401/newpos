use File::Basename;
use Getopt::Long;
use strict;
use 5.010;
my $dir="";
my $cmd="";
my $debug=0;
GetOptions(
	"dir=s" =>\$dir,
	"cmd=s" => \$cmd,
	"debug=s" => \$debug,
);

&parsedir($dir);
sub parsedir(@_)
{
	my $dir=shift @_;
	if (-d $dir)
	{
		opendir DH ,$dir;
		for my $file(readdir DH)
		{
			next if $file=~/^\.{1,2}$/;
			&parsedir("$dir/$file");
		}
	}
	else
	{
		my $file=$dir;
		next if $file!~/prc\.csv/;
		print STDERR "$file\n";
		my @arr=();
		open(IN,$file);
		while(<IN>)
		{
			my $line=$_;
			next if $line =~/,,,,,,,/;
			push @arr,$line;
		}
		close IN;
		
		open(OUT , " > $file");
		for my $line(@arr)
		{
			print OUT $line;
		}
		close OUT;
#		exit;
	}
}