package WPOS;
use strict;
use 5.22.0;
use experimental 'smartmatch';
use LWP::Simple;
use Encode;
use Encode::Guess;
use FindBin qw($Bin);
use File::Path qw(make_path);


use Encode;
use Encode::CN;
use Encode::Detect::Detector;


use lib "c:/code";
use WEXCFG;WEXCFG->new();
use WNET;WNET->new();



use Exporter();
our @ISA=qw(Exporter);
our @EXPORT=(@EXPORT,
	"gettoday",
	"inclass",
	"getdscvt",

	"utf82gbk",
	"gbk2utf8",

	"downloadurl",

	"downloadprice",
	"downloadpos",

	"parseprice",
	"parsepos",
	
	"checksumds",
	);

my %priceh;
my %posh;
our $exg;
our $ctr;
our $date;
my $filedir;

#程序流程说明
#	1.下载每日成交持仓数据
#	2.解析每日成交持仓数居并存储
#	3.加载每日成交持仓数据（对于某些以品种分类的持仓，要计算其价格数据的加权平均值）
#	4.生成持仓文件
#每日价格格式
#	通用格式
#	dt mctr ctr o h l c js vol pos dif1 dif2
#	
#	每个交易所提供的数据不同，这里是4个交易所都支持的数据
#	在price文件夹 20140101.csv
#
#每日持仓格式
#	通用格式
#	dt ctr 多空成交 排名 公司名 手数 增减 
#	20140221	p	多	91	同信久恒	407	-139

sub new 
{
	my $self = {};
	$filedir="$Bin/$exg/files";
	make_path $filedir unless -d $filedir;
	bless $self;
	return $self;
}
sub init
{
	my $self = shift @_;
	$filedir="$Bin/$exg/files";
	make_path $filedir unless -d $filedir;
}
sub downloadprice()
{
	my $file="$filedir/${date}_prc.txt";
	if ($exg eq 'zj')
	{
		my ($year,$mon,$day)=($date=~/(\d{4})(\d{2})(\d{2})/);
		my $url="http://www.cffex.com.cn/fzjy/mrhq/${year}${mon}/${day}/index.xml";
		&downloadurl($url,$file,'refresh:force,utf82gbk') unless &prcfileavailablezj();
	}
	if ($exg eq 'sq')
	{
		my $url="http://www.shfe.com.cn/data/dailydata/kx/kx${date}.dat";
		&downloadurl($url,$file,"refresh:$date,size:10000,utf82gbk");
	}
	if ($exg eq 'ds')
	{
		return unless $date>20010507;
		my $url="http://www.dce.com.cn/PublicWeb/MainServlet?action=Pu00012_download&Pu00011_Input.trade_date=${date}&Pu00011_Input.variety=all&Pu00011_Input.trade_type=0&Submit2=%CF%C2%D4%D8%CE%C4%B1%BE%B8%F1%CA%BD";
		&downloadurl($url,$file,"size:3000");
	}
	if ($exg eq 'zs')
	{	
		my ($year,$mon,$day)=($date=~/(\d{4})(\d{2})(\d{2})/);
		my $url="http://www.czce.com.cn/portal/exchange/$year/datadaily/${date}.txt";
		$url="http://www.czce.com.cn/portal/exchange/jyxx/hq/hq${date}.html" if $date>=20050429 and $date<=20100825;
		&downloadurl($url,$file,"sameday");
	}
}
sub downloadpos()
{
	my $file="$filedir/${date}_pos.txt";
	if ($exg eq 'zj')
	{
		my ($year,$mon,$day)=($date=~/(\d{4})(\d{2})(\d{2})/);
		&downloadposzj()
	}
	if ($exg eq 'sq')
	{
		my $url="http://www.shfe.com.cn/data/dailydata/kx/pm${date}.dat";
		&downloadurl($url,$file,"refresh:$date,size:10000,utf82gbk");
	}
	if ($exg eq 'ds')
	{
		return unless $date>20010507;
		&downloadposds();
	}
	if ($exg eq 'zs')
	{		
		my ($year,$mon,$day)=($date=~/(\d{4})(\d{2})(\d{2})/);
		my $url="http://www.czce.com.cn/portal/exchange/${year}/datatradeholding/${date}.txt";
		$url="http://www.czce.com.cn/portal/exchange/jyxx/pm/pm${date}.html" if $date>=20050429 and $date<=20100825;		
		&downloadurl($url,$file,"sameday");
	}

}
sub parseprice()
{
	my $infile="$filedir/${date}_prc.txt";
	my $outfile="$filedir/${date}_prc.csv";
	if ($exg eq 'zj')
	{
		my @plists;
		open(OUT ," > $outfile") or die "Cannot open $outfile\n";
		#my @header=qw/日期 品种 合约 开 高 低 收 结算 成交 持仓 成交金额/;
		my $tline="";
		open (IN,"$infile") or die "Cannot open file $infile\n";
		while(<IN>)
		{
			s/\s+$//;
			s/\s+//ig;
			my $line=$_;
			next unless $line;
			next if /xml version/;
			next if /dailydatas/;
			$tline="${tline}$line";
		}
		return if $tline=~/您要查看的网页可能已被删除/;
		my @lines=split/<\/dailydata><dailydata>/,$tline;
		for(@lines){&formatlinepricezj($_)};
		close OUT;
	}
	if ($exg eq 'sq')
	{
		my $text="";
		open(IN,"$infile");while(<IN>){$text.=$_}close IN;
		open(OUT ," > $outfile");
		my @a=(split/PRODUCTID/,$text);
		for(@a)
		{
			s/PRICE//ig;
			s/"//ig;
			s/OPENINTEREST/OPT/ig;
			s/ //ig;
			&formatlinepricesq($_);
		}
		close OUT;
	}
	if ($exg eq 'ds')
	{
		return unless $date>20010507;
		open (OUT ," > $outfile")or die "Cannot open outfile $outfile";
		open (IN,"$infile") or die "Cannot open infile $infile";
		while(<IN>)
		{
			my @eh=(split);
			next unless $eh[-1];
			next unless $eh[2];
			next if $eh[2] eq '-';
			next unless $eh[1];
			next unless $eh[1]=~/^\d+$/;
			next if ($eh[0]=~/小计/);
			$eh[1]=~s/\d{2}(\d{4})/$1/;
			if(defined $WEXCFG::chn2eng{$eh[0]})#每个合约
			{
				print OUT "$date,$WEXCFG::chn2eng{$eh[0]},$WEXCFG::chn2eng{$eh[0]}$eh[1],";
				my @plist=@eh[2,3,4,5,7,10,11,8,9];
				my $pl=join",",@plist;
				print OUT "$pl\n";
			}
		}
		close IN;
		close OUT;
	}
	if ($exg eq 'zs')
	{
		my $infile="$filedir/${date}_prc.txt";
		my $outfile="$filedir/${date}_prc.csv";
		open(IN,"$infile") or die "Cannot open infile $infile\n";
		open(OUT ," > $outfile") or die "Cannot open outfile $outfile\n";
		if ($date>=20050429 and $date<=20100825)
		{
			my $line="";
			while(<IN>)
			{
				s/\s+$//;
				next unless  /td|tr|table/;
				next if /font/;
				next if /bottom/;
				s/\s+$//;
				s/\s//ig;
				s/tdalign//ig;
				s/rightclass//ig;
				s/tdformat//ig;
				s/centerclass//ig;
				s/left//ig;
				s/\=//ig;
				s/\&nbsp\;//ig;
				s/\/td//ig;
				s/<>//ig;
				s/<\/tr><tr>/#/ig;
				s/<tdclassalignright>//ig;
				s/<tdclassalign>//ig;
				s/,//ig;
				next unless /\S/;
				#print"$_\n";
				$line.=",$_";
			}
			
			
			my @aa=(split/<\/tr>,<tr>/,$line);
			for(@aa)
			{
				next if /tablewidth/;
				next if /小计/;
				next if /总计/;
				my @a=(split/,/);
				shift @a;
				#print"@a\n";
				#print "###  $_\n";
				my ($mctr)=($a[0]=~/^(\D+)\d/);
				#print"@a\n";
			#	print OUT "$date,$mctr,$a[0],$a[2],$a[3],$a[4],$a[5],$a[6],$a[9],$a[10],$a[7],$a[8]\n";
				my $dif1=$a[5]-$a[1];#8 chengjiao  9chicang
				print OUT "$date,$mctr,$a[0],$a[2],$a[3],$a[4],$a[5],$a[6],$a[8],$a[9],$dif1,$a[7]\n" if $a[2];#有些天连open都没有
			}			
		}
		else
		{
			while(<IN>)
			{
				s/\s+$//;
				next if /郑州商品交易所/;
				next if /小计/;
				next if /总计/;
				next unless $_;
				my @a=(split/,/);
				#品种月份	 昨结算	今开盘	 最高价	 最低价	 今收盘	 今结算	 涨跌1	 涨跌2	 成交量(手)	空盘量	增减量	 成交额(万元)	交割结算价
				#dt mctr ctr o h l c js vol pos dif1 dif2
				
				my ($mctr)=($a[0]=~/^(\D+)\d/);
				#print"@a\n";
				print OUT "$date,$mctr,$a[0],$a[2],$a[3],$a[4],$a[5],$a[6],$a[9],$a[10],$a[7],$a[8]\n";
			}
		}
		
		close IN;
		close OUT;
	}
}
sub formatlinepricesq()
{
	my $line=shift @_;
	$line=~s/天然橡胶/橡胶/ig;
	$line=~s/石油沥青/沥青/ig;
	my ($name)=($line=~/:(\D+),DELIVERYMONTH/);
	return unless $name;
	#print "$name\n";
	#return if $name eq '总计';
	my @b=qw!DELIVERYMONTH PRESETTLEMENT OPEN HIGHEST LOWEST CLOSE SETTLEMENT ZD1_CHG ZD2_CHG VOLUME OPT OPTCHG!;
	#my @pb=qw!DELIVERYMONTH PRESETTLEMENT OPEN HIGHEST LOWEST CLOSE SETTLEMENT ZD1_CHG ZD2_CHG VOLUME OPT OPTCHG!;
	my @c=(split/,/,$line);
	
	my %nv;
	for my $nc(@c)
	{
		my($k,$v)=(split/:/,$nc);
	#	print"#$k,$v\n";
		$nv{$k}=$v;
	}
	return unless $nv{'OPEN'};
	return unless $nv{'DELIVERYMONTH'};

	#dt mctr ctr o h l c js vol pos dif1 dif2
	$name=$WEXCFG::chn2eng{$name};
	print OUT "$date,${name},${name}$nv{'DELIVERYMONTH'}";

	for my $nb(qw!OPEN HIGHEST LOWEST CLOSE	SETTLEMENT VOLUME OPT ZD1_CHG ZD2_CHG!)
	{
		print OUT ",$nv{$nb}";
	}
	print OUT "\n";
}
sub parsepos()
{
	my $infile="$filedir/${date}_pos.txt";
	my $outfile="$filedir/${date}_pos.csv";
	if ($exg eq 'zj')
	{
		my %valuetype=
		(
			"0" => "成交",
			"1" => "多",
			"2" => "空",
		);
		my %h;
		my @lists;
		return if -s $outfile;
		open (OUT," > $outfile") or die "Cannot open out $outfile\n";
		open (IN ,"$infile") or die "Cannot open infile $infile\n";
		while(<IN>)
		{
			s/\s+//ig;
			if(/<(.*)>(.*)<\/\g{1}>/)
			{
				my ($v1,$v2)=($1,$2);
				
				#多空数字中文转换
				$v2=$valuetype{$v2} if ($v1 eq 'dataTypeId');
				$h{$v1}=$v2;
			}
			if(/<\/data>/)
			{
				my @header=qw!tradingDay instrumentId dataTypeId rank shortname volume varVolume!;
				my @ps=@h{@header};
				my $p=join",",@ps;
				push @lists,$p;
				print"$p\n";
				print OUT "$p\n";
			}
		}
		close IN;
		close OUT;
	}
	if ($exg eq 'sq')
	{
		my $text="";
		my $infile="$filedir/${date}_pos.txt";
		my $outfile="$filedir/${date}_pos.csv";
		open(IN,"$infile");while(<IN>){$text.=$_}close IN;
		open(OUT ," > $outfile");
		my @a=(split/INSTRUMENTID/,$text);
		for(@a)
		{
			s/PRICE//ig;
			s/"//ig;
			s/ //ig;
			&formatlinepossq($_);
		}
		close OUT;
	}
	if ($exg eq 'ds')
	{
		my $infile="$filedir/${date}_pos.txt";
		my $outfile="$filedir/${date}_pos.csv";
		open(IN,"$infile") or die "Cannot open infile $infile\n";
		open(OUT ," > $outfile") or die "Cannot open outfile $outfile\n";
		my ($nowctr,$type)=("","");
		while(<IN>)
		{
			s/\s+$//;
			next if /大连商品交易所/;
			if(/成交量/){$type="成交";next;}
			if(/持买单量/){$type="多";next;}
			if(/持卖单量/){$type="空";next;}
			if(/品种代码：(\S+)/){$nowctr=$1;next;}
			if(/合约代码：(\S+)/){$nowctr=$1;next;}
#			print"$nowctr $_\n";
			my($seq,$name,$v,$difv)=(split/\s+/);
			next unless $seq  and $seq=~/^\d+$/;
			next unless $v    and $v  =~/^\d+$/;
			next unless $difv=~/\d+$/;
			print OUT "$date,$nowctr,$type,$seq,$name,$v,$difv\n";
#			print "$nowctr $seq,$name,$v,$difv\n";
		}
		close IN;
		close OUT;
	}
	if ($exg eq 'zs')
	{
		my $infile="$filedir/${date}_pos.txt";
		my $outfile="$filedir/${date}_pos.csv";
		open(IN,"$infile") or die "Cannot open infile $infile\n";
		open(OUT ," > $outfile") or die "Cannot open outfile $outfile\n";
		if ($date>=20050429 and $date<=20100825)
		{
			my $line="";  
			my $ctr="";
			while(<IN>)
			{
				#合约代码  WS605               
				#品种  硬麦  
				if(/合约代码\s+(\S+)\s+/){$ctr=$1;}
				if(/品种\s+(\S+)\s+/){$ctr=$1;}
				next unless  /td|tr|table/;
				next if /font/;
				next if /bottom/;
				s/\s+$//;
				s/\s//ig;
				s/tdalign//ig;
				s/rightclass//ig;
				s/tdformat//ig;
				s/centerclass//ig;
				s/left//ig;
				s/\=//ig;
				s/\&nbsp\;//ig;
				s/\/td//ig;
				s/<>/#/ig;
				s/<\/tr><tr>/#/ig;
				next unless /\S/;
				$line.=$_;
				if($ctr)
				{
					$line.="!!!$ctr!!";
					$ctr="";
				}
			}
			my @aa=(split/table/,$line);
			for my $la(@aa)
			{
#				print"$la\n";
#				next;
				$la=~s/早籼/籼稻/ig;
				my ($ctr)=($la=~/!!!(\S+)!!/);
				next unless length $la >10;
				$ctr=defined $WEXCFG::chn2eng{$ctr}?$WEXCFG::chn2eng{$ctr}:$ctr;
				#print STDERR "Cannot find ctr $la" unless $ctr;
				next unless $ctr;
				my @a=(split/<\/tr><tr>/,$la);
				for(@a)
				{
					next unless /#\d+#/;
					s/<\/tr>.*//ig;
					next if />合计</;
					#print "$_\n";
					s/,//ig;
					my @b=(split/#/);
					print OUT "$date,$ctr,成交,$b[1],$b[3],$b[5],$b[7]\n"if $b[3] and $b[7]=~/\d/;
					print OUT "$date,$ctr,多,$b[1],$b[9],$b[11],$b[13]\n"if $b[9] and $b[13]=~/\d/;
					print OUT "$date,$ctr,空,$b[1],$b[15],$b[17],$b[19]\n"if $b[11] and $b[19]=~/\d/;
				}
			}
			
		}
		else
		{
			my $ctr="";
			while(<IN>)
			{
				s/\s+$//;
				s/早籼/籼稻/ig;
				if(/合约：(\S+)/){$ctr=$1;}
				if(/品种：(\S+)/){$ctr=$1;}
				$ctr=defined $WEXCFG::chn2eng{$ctr}?$WEXCFG::chn2eng{$ctr}:$ctr;
				
				next unless /^\d/;
				my @b=(split/,/);
				print OUT "$date,$ctr,成交,$b[0],$b[1],$b[2],$b[3]\n"if $b[1] and $b[3]=~/\d/;
				print OUT "$date,$ctr,多,$b[0],$b[4],$b[5],$b[6]\n"if $b[4] and $b[6]=~/\d/;
				print OUT "$date,$ctr,空,$b[0],$b[7],$b[8],$b[9]\n"if $b[7] and $b[9]=~/\d/;
			}
		}
		
		close IN;
		close OUT;
	}
}
sub formatlinepricezj()
{
	my $line=shift @_;
	#日期 品种 合约 开 高 低 收 结算 成交 持仓 成交金额
	my @ret;
	for my $part(qw/tradingday productid instrumentid openprice highestprice lowestprice closeprice settlementprice volume openinterest /)
	{
		push @ret,&getpart($line,$part);
	}
	my $chg;
	$chg=&getpart($line,'closeprice')     -&getpart($line,'presettlementprice');$chg = sprintf("%.3f", $chg);push @ret,$chg;
	$chg=&getpart($line,'settlementprice')-&getpart($line,'presettlementprice');$chg = sprintf("%.3f", $chg);push @ret,$chg;
	my $l=join",",@ret;
	print OUT "$l\n" if $l!~/,,/;#原因在于有些天TF没有成交 这会导致有几个,,,连着出现
}
sub formatlinepossq()
{
	my $line=shift @_;
	my ($name)=($line=~/^:([^:]+),/);
	return unless $name;
	$line=~s/PARTICIPANT//ig;
	$line=~s/\},\{$//ig;
	
	my %nv;
	my @c=(split/,/,$line);
	for my $nc(@c)
	{
		my($k,$v)=(split/:/,$nc);
		$nv{$k}=$v;
	}
	return if $nv{"RANK"}<1 or $nv{"RANK"}>20; 
	print OUT "$date,${name},成交,$nv{'RANK'},$nv{'ABBR1'},$nv{'CJ1'},$nv{'CJ1_CHG'}\n";
	print OUT "$date,${name},多,$nv{'RANK'},$nv{'ABBR2'},$nv{'CJ2'},$nv{'CJ2_CHG'}\n";
	print OUT "$date,${name},空,$nv{'RANK'},$nv{'ABBR3'},$nv{'CJ3'},$nv{'CJ3_CHG'}\n";
}
sub prcfileavailablezj()
{
	my $file="$filedir/${date}_prc.txt";
	return 0 unless -s $file;
	open(IN,"$file") or die "Cannot open file $file\n";
	while(<IN>){return 0 if /您要查看的网页可能已被删除/;}
	return 1;
}
sub downloadposzj()
{
	my @ctrs=qw!IF TF!;
	for my $ctr(@ctrs)
	{
		next unless &istrading($date,$ctr);
		my $outfile="$filedir/$ctr/${date}_pos.txt";
		make_path "$filedir/$ctr" unless -d "$filedir/$ctr";
		my ($year,$mon,$day)=($date=~/(\d{4})(\d{2})(\d{2})/);
		my $url="http://www.cffex.com.cn/fzjy/ccpm/${year}${mon}/${day}/${ctr}.xml";
		&downloadurl($url,$outfile,"size:10000,utf82gbk");
	}
	my $outfile="$filedir/${date}_pos.txt";
	open (OUT , " > $outfile") or die "Cannot open outfile $outfile\n";
	for my $ctr(@ctrs)
	{
		next unless &istrading($date,$ctr);
		my $infile="$filedir/$ctr/${date}_pos.txt";
		open(IN,"$infile") or die "Cannot open infile $infile\n";
		while(<IN>){print OUT $_ ;}
		close IN;
	}
	close OUT;
}
sub downloadposds()
{
	my $infile="$filedir/${date}_prc.txt";
	if (! -s $infile){&downloadprice();}
	#open(IN,"$infile") or die "Cannot open pricefile $infile\n";
	my %ctrs;
	{
		open (IN,"$infile") or die "Cannot open infile $infile";
		while(<IN>)
		{
			my @eh=(split);
			next unless $eh[1];
			next unless $eh[1]=~/^\d+$/;
			next if ($eh[0]=~/小计/);
			$eh[1]=~s/\d{2}(\d{4})/$1/;
			if(defined $WEXCFG::chn2eng{$eh[0]})#每个合约
			{
				$ctrs{"$WEXCFG::chn2eng{$eh[0]}$eh[1]"}=1;
				$ctrs{"$WEXCFG::chn2eng{$eh[0]}"}=1;
			}
		}
		close IN;
	}
	#my @ww=sort keys %ctrs;print "@ww\n";exit;
	
	for my $ctr(sort keys %ctrs)
	{
		my $outfile="$filedir/$ctr/${date}_pos.txt";
		make_path "$filedir/$ctr" unless -d "$filedir/$ctr";
		my $url;
		$url="http://www.dce.com.cn/PublicWeb/MainServlet?action=Pu00022_download_1&Pu00021_Input.prefix=${date}_${ctr}&Pu00021_Input.trade_date=${date}&Pu00021_Inpt=0&Pu00021_Input.content=1&Pu00021_Input.content=2&Pu00021_Input.variety=${ctr}&Pu00021_Input.trade_type=0&Pu00021_Input.contract_id=&Submit2=%CF%C2%D4%D8%CE%C4%B1%BE%B8%F1%CA%BD";
		my ($mctr)=($ctr=~/(\D+)/);
		$url="http://www.dce.com.cn/PublicWeb/MainServlet?action=Pu00022_download&Pu00021_Input.prefix=${date}_${ctr}&Pu00021_Input.trade_date=${date}&Pu00021_Input.content=0&Pu00021_Input.content=1&Pu00021_Input.content=2&Pu00021_Input.variety=${mctr}&Pu00021_Input.trade_type=0&Pu00021_Input.contract_id=${ctr}&Submit2=%CF%C2%D4%D8%CE%C4%B1%BE%B8%F1%CA%BD" if $ctr=~/\d/;
		next unless &istrading($date,$mctr);
		next if &alreadyupdatedds($date,$ctr);
		&downloadurl($url,$outfile,"size:500")
	}
	
	my $outfile="$filedir/${date}_pos.txt";
	open (OUT , " > $outfile") or die "Cannot open outfile $outfile\n";
	for my $ctr(sort keys %ctrs)
	{
		my $infile="$filedir/$ctr/${date}_pos.txt";
		open(IN,"$infile") or die "Cannot open infile $infile\n";
		while(<IN>){print OUT $_ ;}
		close IN;
	}
	close OUT;
}
sub loadprice()
{
	my $file=shift @_;
	my %a;
	
}
sub loadpos()
{
	my $file=shift @_;
	my %a;
}
sub gettoday()
{
	my($t)=@_;
	$t=time unless $t;
	my @today=localtime($t);
	my $td=$today[3]+100*($today[4]+1)+10000*($today[5]+1900);
	return $td;
}
sub testfilecode()
{
	my $file=shift @_;
	use Encode::Guess qw/euc-jp shiftjis/;
	use Encode;
	my $str_Line;

    open(FH,"$file");
    $str_Line = <FH>;
    close(FH);
    my $str_Encoding;                          
    $str_Encoding = Encode::Guess->guess($str_Line)->name;
#    print STDERR "GUESS encoding $file $str_Encoding\n";
	say detect($str_Line) ;
	return $str_Encoding;
}
sub downloadurl()
{
	my ($url,$file,$type)=@_;
	my $setsize=0;
	my @types=$type?(split/,/,$type):();
	#print @types;
	if(/refresh:force/~~@types and -e $file)#强制删除原有文件
	{
		unlink $file;
	}
	if(/refresh:today/~~@types and -e $file)#删除今天下载的原有文件
	{
		my ($t)=(stat($file))[-5];
		my $dt=&gettoday($t);
		unlink $file if $dt eq &gettoday();
	}
	if(/refresh:(\d{8})/~~@types and -e $file)
	#删除当日16:00前下载的文件 上期所：其更新时间一般为20点左右 大商所：历史数据的时间在本地更新的时间 郑商所：15点半左右  中金所：20点
	#设定的规则是16:00前下载的要重下
	#问题在于上期所的delay数据 程序调用时仅对上期所进行此项操作，否则会造成重复下载郑商所数据的问题
	{
		my $setdt=$1;
		my $t=(stat($file))[-4];
		my($sec,$min,$hour,$day,$mon,$year)=localtime $t;
		$day+=100*($mon+1)+10000*($year+1900);
		unlink $file if($setdt==$day and $hour<16);
	}
	if(/size:(\d+)/~~@types)#在已下载文件大小小于设定值时才下载
	{
		$setsize=$1;
		my $sz= -s $file;$sz+=0;
		return if $sz > $setsize;
	}
	if(/sameday/~~@types and -e $file)
	{
		my ($t)=(stat($file))[9];
		my $dt=&gettoday($t);
		unlink $file if $dt != $date;
	}
	
	for (1..10)
	{
	
		my $sz= -s $file;$sz+=0;
		if ($sz<=$setsize)
		{
			#system($cmd);
			print "in 1 10 $url $file $type\n";
			dl_url($url,$file);
			#在此加入转码以避免对存在的文件进行转码，以防2次转码 
			&utf82gbk($file) if(/utf82gbk/~~@types or &file_is_utf8($file));
			#没有设定文件大小时只下载一次
			return if -s $file and !$setsize;
			$sz= -s $file;$sz+=0;
			print "$file sz $sz setsize $setsize\n";
			return if $setsize and $sz>=$setsize;
		}
	}
#		print "$cmd\n";exit;

}
sub utf82gbk()
{
	my $file=shift @_;
	print"utf8 to gbk $file\n";
	return unless -s $file;
	my @arr=();
	open(IN,$file);
	while(<IN>)
	{
		my $line=$_;
#		print $line;
		$line = encode("gbk", decode("utf8", $line));
#		print $line;
		push @arr,$line;
	}
	close IN;
	print"changing u2g $file\n";
	open(OUT , " > $file");
	for my $line(@arr)
	{
		print OUT $line;
	}
	close OUT;
}
sub gbk2utf8()
{
	my $file=shift @_;
	return unless -s $file;
	my @arr=();
	open(IN,$file);
	while(<IN>)
	{
		my $line=$_;
		$line = encode("utf-8",decode("gbk",$line));
		push @arr,$line;
	}
	close IN;
	
	open(OUT , " > $file");
	for my $line(@arr)
	{
		print OUT $line;
	}
	close OUT;
}
sub getpart()
{
	my ($line,$part)=@_;
	my ($ret)=($line=~/<$part>(.*)<\/$part>/);
	return $ret;
}
sub istrading()
{
	my ($date,$ctr)=@_;
	return 0 if $ctr eq 'jm'	and $date <20130322;
	return 0 if $ctr eq 'i'	and $date <20131018;
	return 0 if $ctr eq 'jd'	and $date <20131108;
	return 0 if $ctr eq 'fb'	and $date <20131206;
	return 0 if $ctr eq 'bb'	and $date <20131206;
	return 0 if $ctr eq 'TF'	and $date <20130906;
	return 1;
}
sub alreadyupdatedds()
{
	my ($date,$ctr)=shift @_;
	my $file="$filedir/$ctr/${date}_pos.txt";
	return 0 unless -s $file;
	return 0 unless -M $file >2;
	return 1;
}
sub checksumds()#大商所存在合约加和与品种数不等的情况 函数检测此错误，并给出相应日期的正确输出
{
	my $file=shift @_;
	my %ds;
	my %loaddt;
	my %errdt;
	my @errmessage;
	if(! open(SUMIN,"$file"))
	{
		warn "Cannot open check sum file $file\n";
		return;
	}	
	while(<SUMIN>)
	{
		s/\s+$//;
		my ($dt,$ctr,$type,$seq,$name,$v,$vdif)=(split/,/);
		
		print  STDERR "loaddate $dt\n" unless defined $loaddt{$dt};
		$loaddt{$dt}=1;
		
		if ($ctr=~/\d{4}/)
		{
			my($c)=($ctr=~/(.*)\d{4}/);
			$ds{$dt}{$name}{$c}{$type}{'v'}{$ctr}=$v;
			$ds{$dt}{$name}{$c}{$type}{'vd'}{$ctr}=$vdif;
		}
		else
		{
			$ds{$dt}{$name}{$ctr}{$type}{'v'}{'main'}=$v;
			$ds{$dt}{$name}{$ctr}{$type}{'vd'}{'main'}=$vdif;
		}	
	}
	close SUMIN;

	my $d=0;
	for my $dt(sort keys %ds)
	{
		$ds{$d}=undef if $d;
		$d=$dt;
		for my $name(sort keys %{$ds{$dt}})
		{
			for my $c(sort keys %{$ds{$dt}{$name}})
			{
				for my $type(sort keys %{$ds{$dt}{$name}{$c}})
				{
					for my $dif(qw!v vd!)
					{	
						my $total=$ds{$dt}{$name}{$c}{$type}{$dif}{'main'};$total+=0;
						my $sumtotal=0;

						for my $ctr(sort keys %{$ds{$dt}{$name}{$c}{$type}{$dif}})
						{
							
							next if $ctr eq 'main';
							$sumtotal+=$ds{$dt}{$name}{$c}{$type}{$dif}{$ctr};
						}
						if($sumtotal!=$total)
						{
							#$errdt{$dt}{$dif}=1;
							#push @errmessage,"$dt $name $c $type $dif total1:$total total2:$sumtotal\n";
							print "$dt,$name,$c,$type,$dif,total1,$total,total2,$sumtotal\n";
							#print STDERR "$dt $name $c $type value total1:$total total2:$sumtotal\n";
						}
					}				
				}
			}
		}
	}
}
sub file_is_utf8()
{
#	return 1;
	my $file=shift @_;
	my $line="";
	#my $ret=0;
	open(IN," $file");
	while(<IN>)
	{
		$line.=$_;
		#$ret=1 if(index($_,'encoding="UTF-8"')!=-1);
	}
	
	close IN;
	say detect($line) ;
	return 0 if(detect($line) =~ /gb/);
	return 1;
}
1;