use Test::More tests => 18;
#use Test::More qw(no_plan);
use File::Spec;
use FindBin;
use lib (
    File::Spec->catfile($FindBin::Bin,"lib"),
    File::Spec->catfile($FindBin::Bin, File::Spec->updir, "lib"),
    );

BEGIN { use_ok('IPC::Mutex::Flock') };

my $sm;


#-- method cleanup()
$sm = IPC::Mutex::Flock->new;
eval {
    $sm->cleanup;
};
ok( ! $@, "cleanup" );

$sm->cleanup;
undef $sm;


#-- constract
$sm = IPC::Mutex::Flock->new;
ok($sm, "instance");
isa_ok($sm, 'IPC::Mutex');
isa_ok($sm, 'IPC::Mutex::Flock');
is( $sm->key, $IPC::Mutex::DEFAULT_KEY, "default key is \$IPC::Mutex::DEDAULT_KEY");
is( $sm->delay, 0, "default delay is 0");
is( $sm->interval, undef, "default interval is undef");

$sm->cleanup;
undef $sm;


#-- set init
$sm = IPC::Mutex::Flock->new;
$sm->_init({'key'=>'AAA','delay'=>100,'interval'=>999,'prefix'=>'foo',});
is( $sm->key, 'AAA', "init key");
is( $sm->delay, 100, "init delay");
is( $sm->interval, 999, "init interval");
is( $sm->_prefix, 'foo', "init _prefix");

$sm->cleanup;
undef $sm;


#-- setter/getter
$sm = IPC::Mutex::Flock->new;

$sm->key('BBB');
is( $sm->key, 'BBB', "set key");

$sm->delay(444);
is( $sm->delay, 444, "set delay");

$sm->interval(555);
is( $sm->interval, 555, "set interval");

$sm->_prefix('ppp');
is( $sm->_prefix, 'ppp', "set _prefix");

is( $sm->_mk_lockfile_name, "ppp.BBB", "_mk_lockfile_name");

$sm->cleanup;
undef $sm;


#-- method critical()
$sm = IPC::Mutex::Flock->new;
eval {
    $sm->critical(sub {});
};
ok( ! $@, "critical()" );

$sm->cleanup;
undef $sm;


1;
