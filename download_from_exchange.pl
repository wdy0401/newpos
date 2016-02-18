use 5.010;
use strict;
use Getopt::Long;

use FindBin qw($Bin);
use lib "$Bin";
use WPOS;

my ($date,$exchg)=("20140326",'ds');
GetOptions(
    "date=s"   => \$date,
    "exchg=s"  => \$exchg,
);
exit if $date<20100416 and $exchg eq 'zj';
exit if $date<20020107 and $exchg eq 'sq';
exit if $date<20010508 and $exchg eq 'ds';
exit if $date<20050429 and $exchg eq 'zs';
print "Download EXCHANGE: $exchg  DATE: $date\n";
$WPOS::date=$date;
$WPOS::exg=$exchg;
WPOS->init();
&downloadprice();
&parseprice();
&downloadpos();
&parsepos();