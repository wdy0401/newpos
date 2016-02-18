use 5.010;
use Getopt::Long;
use FindBin qw($Bin);
use File::Copy;

my ($date)=("20140321");
GetOptions(
    "date=s"   => \$date,
);

&rundir("$Bin/sq");
&fix(qw!sq!);
sub fix()
{
	for $exchg(@_)
	{
		for $type(qw!volume long short!)
		{
			$file="$Bin/$exchg/sqlfile/${type}.csv";
			&fixfile($file);
		}
	}
}
sub fixfile()
{
	my ($file)=@_;
	return unless -s $file;
	my $bkfile="${file}.bak";
	print STDERR "fixfile $file\n";
	open(IN,"$file");
	open(OUT," > $bkfile");
	
	while(<IN>)
	{
		print OUT $_ unless /^$date/;
	}
	close IN;
	close OUT;
	unlink $file;
	move($bkfile,$file);
	
}
sub rundir()
{

	my ($nowdir)=@_;
	
	print STDERR "run dir  $nowdir\n";
	opendir DH ,$nowdir;
	foreach (readdir DH)
	{
		my $file=$_;
		next if $file=~/^\.+$/;
		&rundir("$nowdir/$file")if -d "$nowdir/$file";
		runfile("$nowdir/$file","$file")if ! -d "$nowdir/$file";		
	}
}
sub runfile()
{
	my ($nowfile,$file)=@_;
	#print "$nowfile $file\n";
	if ($file=~/^$date/)
	{
		print STDERR "unlink file $nowfile\n";
		unlink $nowfile;
	}
}
