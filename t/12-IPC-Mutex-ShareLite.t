use Test::More tests => 15;
#use Test::More qw(no_plan);
use File::Spec;
use FindBin;
use lib (
    File::Spec->catfile($FindBin::Bin,"lib"),
    File::Spec->catfile($FindBin::Bin, File::Spec->updir, "lib"),
    );


BEGIN { use_ok('IPC::Mutex::ShareLite') };

my $sm;


#-- method cleanup()
$sm = IPC::Mutex::ShareLite->new;
eval {
    $sm->cleanup;
};
ok( ! $@, "cleanup" );

$sm->cleanup;
undef $sm;


#-- constract
$sm = IPC::Mutex::ShareLite->new;
ok($sm, "instance");
isa_ok($sm, 'IPC::Mutex');
isa_ok($sm, 'IPC::Mutex::ShareLite');
is( $sm->key, $IPC::Mutex::DEFAULT_KEY, "default key is \$IPC::Mutex::DEDAULT_KEY");
is( $sm->delay, 0, "default delay is 0");
is( $sm->interval, undef, "default interval is undef");

$sm->cleanup;
undef $sm;


#-- set init
$sm = IPC::Mutex::ShareLite->new;
$sm->_init({'key'=>'AAA','delay'=>100,'interval'=>999});
is( $sm->key, 'AAA', "init key");
is( $sm->delay, 100, "init delay");
is( $sm->interval, 999, "init interval");

$sm->cleanup;
undef $sm;


#-- setter/getter
$sm = IPC::Mutex::ShareLite->new;

$sm->key('BBB');
is( $sm->key, 'BBB', "set key");

$sm->delay(444);
is( $sm->delay, 444, "set delay");

$sm->interval(555);
is( $sm->interval, 555, "set interval");

$sm->cleanup;
undef $sm;


#-- method
$sm = IPC::Mutex::ShareLite->new;
eval {
    $sm->critical(sub {});
};
ok( ! $@, "critical()" );

$sm->cleanup;
undef $sm;


1;
