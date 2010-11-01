use Test::More tests => 18;
#use Test::More qw(no_plan);
use File::Spec;
use FindBin;
use lib (
    File::Spec->catfile($FindBin::Bin,"lib"),
    File::Spec->catfile($FindBin::Bin, File::Spec->updir, "lib"),
    );

BEGIN { use_ok('IPC::Mutex') };

my $sm;


#-- method cleanup()
$sm = IPC::Mutex->new;
eval {
    $sm->cleanup;
};
ok( ! $@, "cleanup" );

$sm->cleanup;
undef $sm;


#-- constract
$sm = IPC::Mutex->new;
ok($sm, "instance");
isa_ok($sm, 'IPC::Mutex');
is( $sm->key, $IPC::Mutex::DEFAULT_KEY, "default key");
is( $sm->delay, 0, "default delay is 0");
is( $sm->interval, undef, "default interval is undef");

$sm->cleanup;
undef $sm;


#-- set _init
$sm = IPC::Mutex->new;
$sm->_init({'key'=>'2345', 'delay'=>100,'interval'=>999});
is( $sm->key, '2345', "init key");
is( $sm->delay, 100, "init delay");
is( $sm->interval, 999, "init interval");

$sm->cleanup;
undef $sm;


#-- setter/getter
$sm = IPC::Mutex->new;

$sm->key('AAA');
is( $sm->key, 'AAA', "set key");

$sm->delay(444);
is( $sm->delay, 444, "set delay");

$sm->interval(555);
is( $sm->interval, 555, "set interval");

$sm->cleanup;
undef $sm;


#-- method validate()
$sm = IPC::Mutex->new;
like( $sm->_validate(), qr/missing task/, "missing task" );
$sm->cleanup;
undef $sm;

$sm = IPC::Mutex->new;
like( $sm->_validate(1), qr/task is not CODE ref/, "missing task" );
$sm->cleanup;
undef $sm;

$sm = IPC::Mutex->new;
$sm->delay('a');
like( $sm->_validate(sub {}), qr/invalid value of delay/, "invalid value of delay" );
$sm->cleanup;
undef $sm;

$sm = IPC::Mutex->new;
ok( ! $sm->_validate(sub {}), "critical()" );
$sm->cleanup;
undef $sm;


#-- method critical()
$sm = IPC::Mutex->new;
eval {
    $sm->critical(sub {});
};
like( $@, qr/::critical\(\) is not be implemented yet/, "not implemented" );
$sm->cleanup;
undef $sm;


1;
