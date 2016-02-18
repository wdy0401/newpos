#!/usr/bin/perl -w 
use Getopt::Long;
use FindBin qw($Bin);
use 5.010;
use lib "c:/code";
use WEXCFG;WEXCFG->new();
my $posdir="";
my $updatepos="";
my %pmainh;
my %pindexh;
my %loadedfile;
GetOptions(
    "posdir=s"  => \$posdir,
	"updatepos=s"=>\$updatepos,
);
$posdir="$Bin/pos" unless $posdir;
if ($updatepos)
{
	chdir "$posdir";
	system("bat.bat");
	chdir $Bin;
}
my $rootdir="$Bin/mainindex";
my $indexdir="$Bin/mainindex/index";
my $mainctrdir="$Bin/mainindex/mainctr";
mkdir $rootdir    unless -d $rootdir;
mkdir $indexdir   unless -d $indexdir;
mkdir $mainctrdir unless -d $mainctrdir;

for my $ctr(sort keys %WEXCFG::eng2chn)
#for my $ctr(qw!TF!)
{
	&findmainctr("mainctr",$ctr);
	&findmainctr("index",$ctr);
}
sub findmainctr()
{
	my $mainindex=shift @_;
	my $ctr=shift @_;
	print STDERR "PARSING $mainindex $ctr\n";
	my @days=&getdays($mainindex,$ctr);
	return unless @days;
	my @plists=&genmainindexctr($mainindex,$ctr,@days);
	
	my $plist=join"\n",@plists;
	return unless $plist=~/\S/;
	my $file="$Bin/mainindex/$mainindex/${ctr}.csv";
	open(FH, " >> $file");
	print FH "$plist\n";
	close FH;
}
sub genmainindexctr()
{
	my $mainindex=shift @_;
	my $ctr=shift @_;
	my @days=@_;
	my @res;


	my $dir="$Bin/$WEXCFG::ctr2exg{$ctr}/files";
	opendir(DH ,"$dir") or die "Cannot open dir handle $dir\n";
	for my $file(readdir DH)
	{
		next if $loadedfile{"$dir/$file"};
		next unless $file=~/prc/;
		next unless $file=~/csv/;
		my ($filedate)=($file=~/(\d{8})/);
		next unless $filedate~~@days;
		
		my @head=qw!date c ctr open high low close js vol pos dif1 dif2!;
		open (IN ,"$dir/$file") or die "Cannot open file $file\n";
		#print"Parseing file $file\n";
		while(<IN>)
		{
			s/\s+$//;
			next unless /\S/;
			my @a=(split/,/);
			my %b;
			@b{@head}=@a;
			#print"$a[0] $a[1] $a[2]\n";exit;
			$pmainh{$a[0]}{$a[1]}{$a[2]}=\%b;
		}
		$loadedfile{"$dir/$file"}=1;
	}

	if($mainindex eq 'mainctr')
	{
		for my $d(@days)#把每天的主力找出来
		{
			#print "$ctr\n";
			next if ! defined $pmainh{$d}{$ctr};
			#print "2$ctr\n";
			my $vol=-1;
			my $mn;
			for $ctrd(sort keys %{$pmainh{$d}{$ctr}})
			{
				#print "$ctr $ctrd\n";exit;
					
				next if $ctrd=~/^\d+$/;
				if ($pmainh{$d}{$ctr}{$ctrd}->{'vol'}>$vol)
				{
					#print "$ctr $ctrd\n";exit;
					$vol=$pmainh{$d}{$ctr}{$ctrd}->{'vol'};
					$mn=$pmainh{$d}{$ctr}{$ctrd};
					next;
				}
			}
			next unless $mn;
			my %mnh=%$mn;
			#print keys %mnh;
			#$pmainh{$d}{$ctr}{'0'}=$mn;
			my @lists=@mnh{qw!date date ctr open high low close js vol pos!};
			#print "@lists\n";
			$lists[1]=$ctr;
			my $list=join",",@lists;
			push @res,$list;		
		}
	}
	if($mainindex eq 'index')
	{
		for my $d(@days)#把每天的主力找出来
		{
			#print "$ctr\n";
			next if ! defined $pmainh{$d}{$ctr};
			#print "2$ctr\n";
			my $vol=0;
			my $pos=0;
			my $povol=0;
			my $phvol=0;
			my $plvol=0;
			my $pcvol=0;
			my $pjvol=0;
			for $ctrd(sort keys %{$pmainh{$d}{$ctr}})
			{
					
				next if $ctrd=~/^\d+$/;
				$vol+=$pmainh{$d}{$ctr}{$ctrd}->{'vol'};
				$pos+=$pmainh{$d}{$ctr}{$ctrd}->{'pos'};
				print "{$d}{$ctr}{$ctrd}" if $pmainh{$d}{$ctr}{$ctrd}->{'vol'} eq '-' or $pmainh{$d}{$ctr}{$ctrd}->{'open'} eq '-';
				print " no open $ctr $d\n" unless $pmainh{$d}{$ctr}{$ctrd}->{'open'};
				$povol+=$pmainh{$d}{$ctr}{$ctrd}->{'vol'}*$pmainh{$d}{$ctr}{$ctrd}->{'open'};
				$phvol+=$pmainh{$d}{$ctr}{$ctrd}->{'vol'}*$pmainh{$d}{$ctr}{$ctrd}->{'high'};
				$plvol+=$pmainh{$d}{$ctr}{$ctrd}->{'vol'}*$pmainh{$d}{$ctr}{$ctrd}->{'low'};
				$pcvol+=$pmainh{$d}{$ctr}{$ctrd}->{'vol'}*$pmainh{$d}{$ctr}{$ctrd}->{'close'};
				$pjvol+=$pmainh{$d}{$ctr}{$ctrd}->{'vol'}*$pmainh{$d}{$ctr}{$ctrd}->{'js'};
			}
			next unless $vol;
			my $povolp=$povol/$vol;
			my $phvolp=$phvol/$vol;
			my $plvolp=$plvol/$vol;
			my $pcvolp=$pcvol/$vol;
			my $pjvolp=$pjvol/$vol;
			my $list="$d,$ctr,$povolp,$phvolp,$plvolp,$pcvolp,$pjvolp,$vol,$pos";
			push @res,$list;		
		}
	}
	return @res;
}
sub getdays()
{
	my ($indexormain,$ctr)=@_;#indexormian index mainctr
	my $today=gettoday();
	my $ld;
	my $file="$Bin/mainindex/${indexormain}/${ctr}.csv";
	
	$ld=0 unless -s "$file";
	my $lastday;
	if (-s "$file")
	{
		open(INDATE,"$file");
		while(<INDATE>)
		{
			my $ld=$_;
			next if $ld=~/^\s+$/;
			$lastday=(split/,/,$ld)[0];
#			print "$lastday $ld\n";
		}
		close INDATE;
#		print "aa $lastday\n";
#		exit;
	}
	else 
	{
		$lastday=0;
	}

	
	my @days;
	my $bizdayfile="$Bin/bizd.txt";
	$bizdayfile="c:/code/bizd.txt" unless -s $bizdayfile;
	die "Cannot find bizdayfile\n" unless -s $bizdayfile;
	#system("cat $bizdayfile");
	#print "cat $bizdayfile";
	open(IN,"$bizdayfile");
	while(<IN>)
	{
		s/\s+//;
		next if /^\s+$/;
		push @days,$_ if $_>$lastday and $_<=$today;
	}
	close IN;
	return @days;
}

sub gettoday()
{
	my @today=localtime(time);
	my $td=$today[3]+100*($today[4]+1)+10000*($today[5]+1900);
	return $td;
}