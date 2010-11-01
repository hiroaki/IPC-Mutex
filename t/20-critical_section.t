use Test::More tests => 2;
#use Test::More qw(no_plan);
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

my @implements = qw(
IPC::Mutex::Flock
IPC::Mutex::ShareLite
);

my $processes = 30;
my $tasks   = 1000;
my $data    = "$0.data";
diag("data file: $data");

for $module (@implements){

    open  OUT, ">$data" or die "cannot open $data for writing: $!";
    print OUT "0\n";
    close OUT or die "cannot close $data: $!";

    my $pm = new Parallel::ForkManager($processes);

    for ( (1..$tasks) ){
        $pm->start and next;
    
        my $task = sub {
            open IN, "<$data" or die "cannot open $data for reading: $!";
            my $cnt = <IN>;
            close IN or die "cannot close $data: $!";
            
            chomp $cnt;
            ++$cnt;
        
            open  OUT, ">$data" or die "cannot open $data for writing: $!";
            print OUT "$cnt\n";
            close OUT or die "cannot close $data: $!";
        };

        $module->new->critical($task);
    
        $pm->finish;
    }
    $pm->wait_all_children;

    open IN, "<$data" or die "cannot open $data for reading: $!";
    my $cnt = <IN>;
    close IN or die "cannot close $data: $!";
    chomp $cnt;
    is($cnt, $tasks, "$module counts");

    # it has to be using the default key for cleanup because $params did not specific key
    $module->new->cleanup;
    
    unlink $data or die "cannot unlink $data: $!";
}

1;
