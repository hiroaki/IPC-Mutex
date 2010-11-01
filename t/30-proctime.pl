use Test::More qw(no_plan);
use File::Spec;
use FindBin;
use lib (
    File::Spec->catfile($FindBin::Bin,"lib"),
    File::Spec->catfile($FindBin::Bin, File::Spec->updir, "lib"),
    );

use Carp;
use IO::Handle;
use IPC::ShareLite;
use IPC::Mutex::Flock;
use IPC::Mutex::ShareLite;
use Math::BigFloat;
use Parallel::ForkManager;
use Time::HiRes;
use Universal::Require;

my @units = (
    #-- normal mutex
    {
        'comment'   => 'normal mutex',
        'processes' => 5,
        'tasks'     => 50,
        'delay'     => 0,
        'sleep'     => 0,
        },
    {
        'comment'   => 'normal mutex',
        'processes' => 5,
        'tasks'     => 25,
        'delay'     => 0,
        'sleep'     => 2,
        },
    #-- delay mode
    {
        'comment'   => 'delay mode',
        'processes' => 5,
        'tasks'     => 50,
        'delay'     => 1,
        'sleep'     => 0,
        },
    {
        'comment'   => 'delay mode',
        'processes' => 5,
        'tasks'     => 25,
        'delay'     => 0,
        'sleep'     => 2,
        },
    #-- intarval mode
    {
        'comment'   => 'interval mode',
        'processes' => 25,
        'tasks'     => 500,
        'interval'  => 0.1,
        'sleep'     => 0,
        },
    {
        'comment'   => 'interval mode',
        'processes' => 25,
        'tasks'     => 500,
        'interval'  => 0.1,
        'sleep'     => 2,
        },
    {
        'comment'   => 'interval mode',
        'processes' => 25,
        'tasks'     => 100,
        'interval'  => 0.5,
        'sleep'     => 0,
        },
    {
        'comment'   => 'interval mode',
        'processes' => 25,
        'tasks'     => 25,
        'interval'  => 2,
        'sleep'     => 0,
        },
);

for my $u ( @units ){
    tests('IPC::Mutex::ShareLite', $u);
}
for my $u ( @units ){
    tests('IPC::Mutex::Flock', $u);
}


sub tests {
    my $module      = shift;
    my $unit        = shift;
    my $file        = "data.".CORE::time().".".$$;

    diag("module for test: $module");
    my ($proctime,$essentialtime,$ok) = tasks( $module, $unit, $file );
    my $step = $essentialtime / $unit->{'tasks'};
    is( $ok, 'ok', "check shared memory");
    ok( $essentialtime < $proctime, "essentialtime=[$essentialtime] proctime=[$proctime] steptime=[$step] tasktime=[@{[$unit->{'sleep'}]}]");
    
    
    my ($min,$max,$avg) = profile($file);
    ok( $step < $min, "min=[$min]");
    ok( $step < $max, "max=[$max]");
    ok( $step < $avg, "avg=[$avg]");
    
    unlink $file or warn "cannot unlink $file: $!";
}


sub tasks {
    my $module      = shift;
    my $unit        = shift;
    my $file        = shift;

    my $comment     = $unit->{'comment'};
    my $processes   = $unit->{'processes'};
    my $tasks       = $unit->{'tasks'};
    my $delay       = $unit->{'delay'};
    my $interval    = $unit->{'interval'};
    my $stoptime    = $unit->{'sleep'};

    my $in_interval_mode = $interval;

    my $essentialtime;
    if( $in_interval_mode ){
        $essentialtime  = $interval * $tasks;
        diag("$comment: interval=[$interval] procs=[$processes] tasks=[$tasks] essentialtime=[$essentialtime] sec at least.");
    }else{
        $essentialtime  = ($delay + $stoptime) * $tasks;
        diag("$comment: delay=[$delay] procs=[$processes] tasks=[$tasks] essentialtime=[$essentialtime] sec at least.");
    }

    my $params = {
        'interval'  => $interval,
        'delay'     => $delay,
        };
    
    my $fh;
    open $fh, '>>', $file or Carp::croak "cannot open $file: $!";
    $fh->autoflush;

    my $global = IPC::ShareLite->new(
        -key     => 'judg',
        -create  => 'yes',
        -destroy => 'no',
    ) or die "cannot create IPC::ShareLite: $!";
    $global->store("ready");


    my $share = undef;
    unless( $in_interval_mode ){
        $share = IPC::ShareLite->new(
            -key     => 'book',
            -create  => 'yes',
            -destroy => 'no',
        );
    }

    my $pm = new Parallel::ForkManager($processes);
    my $t0 = [Time::HiRes::gettimeofday];
    for ( (1..$tasks) ){
        $pm->start and next;


        my $task = sub {

            printf $fh '%.6f%s', scalar Time::HiRes::gettimeofday, "\n";

            if( $share ){ # for delay mode
                if( $share->fetch ){
                    $global->store("ng");
                }else{
                    $global->store("ok") if( $global->fetch eq "ready" );
                }
                $share->store(1);
            }else{
                $global->store("ok") if( $global->fetch eq "ready" );
            }
        
            Time::HiRes::sleep $stoptime if( $stoptime );

            $share and $share->store(0); # for delay mode
        };

        $module->new($params)->critical($task);

        $pm->finish;
    }
    $pm->wait_all_children;
    my $proctime = Time::HiRes::tv_interval($t0);
    
    $fh->close;
    
    # it has to be using the default key for cleanup because $params did not specific key
    $module->new->cleanup;

    # create and destroy instance for cleanup shared memory 'book'
    $share and $share->destroy(1);

    # flagged for destroy    
    $global->destroy(1);
    
    return ($proctime,$essentialtime,$global->fetch);
}


#-- check each interval time of period
sub profile {
    my $file  = shift;
    my $end   = undef;
    my $prev  = undef;
    my $min   = Math::BigFloat->new('999999999999999.9');
    my $max   = Math::BigFloat->new('0.0');
    my $sum   = Math::BigFloat->new('0.0');
    my $count = 0;
    my $reader;
    open $reader, '<', "$file" or die "cannot open $file: $!";
    while( <$reader> ){
        chomp;

        my $fvalue = Math::BigFloat->new($_);
    
        if( defined $prev ){
    
            my $step = $fvalue->copy->bsub( $prev );
    
            if( $step->is_neg ){ # if it is negative
                die "logical error :-(";
            }
    
            if( $step->bcmp( $min ) < 0 ){
                $min = $step->copy;
            }
            
            if( 0 < $step->bcmp( $max ) ){
                $max = $step->copy;
            }
    
            $sum = $sum->copy->badd($step->copy);
            $count += 1;
    
        }
    
        $prev = $fvalue->copy;
    }
    $reader->close;

    my $avg = sprintf '%.6f', $sum->bdiv($count);
    return ($min,$max,$avg);
}

1;
