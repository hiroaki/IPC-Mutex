use Test::More qw(no_plan);
use File::Spec;
use FindBin;
use lib (
    File::Spec->catfile($FindBin::Bin,"lib"),
    File::Spec->catfile($FindBin::Bin, File::Spec->updir, "lib"),
    );

use Carp;
use IPC::ShareLite;
use IPC::Mutex::Flock;
use IPC::Mutex::ShareLite;
use Parallel::ForkManager;
use Time::HiRes;
use Universal::Require;

my @units = (
    #-- normal mutex
    {
        'comment'   => 'normal mutex (1)',
        'processes' => 25,
        'tasks'     => 1000,
        'delay'     => 0,
        'sleep'     => 0,
        'expect'    => 'ok',
        },
    {
        'comment'   => 'normal mutex (2)',
        'processes' => 25,
        'tasks'     => 100,
        'delay'     => 0,
        'sleep'     => 1,
        'expect'    => 'ok',
        },
    #-- delay mode
    {
        'comment'   => 'delay mode (1)',
        'processes' => 5,
        'tasks'     => 50,
        'delay'     => 1,
        'sleep'     => 0,
        'expect'    => 'ok',
        },
    {
        'comment'   => 'delay mode (2)',
        'processes' => 5,
        'tasks'     => 25,
        'delay'     => 0,
        'sleep'     => 2,
        'expect'    => 'ok',
        },
    #-- intarval mode
    {
        'comment'   => 'interval mode (1)',
        'processes' => 5,
        'tasks'     => 10,
        'interval'  => 2,
        'sleep'     => 5,
        'expect'    => 'ng',
        },
    {
        'comment'   => 'interval mode (2)',
        'processes' => 5,
        'tasks'     => 20,
        'interval'  => 2,
        'sleep'     => 0,
        'expect'    => 'ok',
        },
);


for my $u ( @units ){
    tests('IPC::Mutex::Flock', $u);
}

for my $u ( @units ){
    tests('IPC::Mutex::ShareLite', $u);
}

exit 0;



sub tests {
    my $module      = shift;
    my $unit        = shift;

    my $in_interval_mode = $unit->{'interval'};

    my $essentialtime;
    if( $in_interval_mode ){
        $essentialtime  = $unit->{'interval'} * $unit->{'tasks'};
    }else{
        $essentialtime  = ($unit->{'delay'} + $unit->{'sleep'}) * $unit->{'tasks'};
    }

    my $msg = sprintf "module=[%s] %s: mode=[%s] proc=[%d] task=[%d] essentialtime=[%f]",
                $module, $unit->{'comment'}, ($unit->{'interval'} ? 'interval' : 'delay'),
                $unit->{'processes'}, $unit->{'tasks'}, $essentialtime;
    my ($ok) = tasks( $module, $unit );
    is( $ok, $unit->{'expect'}, "protected. $msg");

}

sub tasks {
    my $module      = shift;
    my $unit        = shift;

    my $comment     = $unit->{'comment'};
    my $processes   = $unit->{'processes'};
    my $tasks       = $unit->{'tasks'};
    my $delay       = $unit->{'delay'};
    my $interval    = $unit->{'interval'};
    my $stoptime    = $unit->{'sleep'};

    my $in_interval_mode = $interval;

    my $params = {
        'interval'  => $interval,
        'delay'     => $delay,
        };
    
    my $global = IPC::ShareLite->new(
                    -key     => 'judg',
                    -create  => 1,
                    -destroy => 0,
                    ) or die "cannot create IPC::ShareLite: $!";
    $global->store("ready");

    my $share = IPC::ShareLite->new(
                    -key     => 'book',
                    -create  => 1,
                    -destroy => 0,
                    );
    $share->store("0");

    my $pm = new Parallel::ForkManager($processes);
    for my $n ( (1..$tasks) ){
        $pm->start and next;

        if( $global->fetch ne "ng" ){

            $module->new($params)->critical(sub {
                if( $share->fetch ne "0" ){
                    $global->store("ng");
                }else{
                    $global->store("ok") if( $global->fetch eq "ready" );
                }
    
                $share->store("1");
            
                if( $stoptime ){
                    my $t = sprintf '%d', ($stoptime+0.5);

                    # Time-consuming processing
                    `sleep $t`;
                    # could not use Time::HiRes::sleep( $stoptime ); because
                    # In Flock, if it uses perl's sleep then it wakes up with occurs unlock.
                    # But not ShareLite, why?
                }
    
                $share->store("0");
            });
        }

        $pm->finish;
    }
    $pm->wait_all_children;
    
    my $return_value = $global->fetch;

    # it has to be using the default key for cleanup because $params did not specific key
    $module->new->cleanup;

    # cleanup shared memory
    $global->destroy(1);
    
    return ($return_value);
}

1;
